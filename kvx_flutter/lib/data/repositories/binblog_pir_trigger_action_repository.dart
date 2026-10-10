import 'dart:convert';
import '../../domain/entities/pir_trigger_action.dart';
import '../../domain/repositories/pir_trigger_action_repository.dart';
import '../datasources/binblog_device_datasource.dart';
import '../models/pir_trigger_action_dto.dart';

class BinblogPirTriggerActionRepository implements PirTriggerActionRepository {
  final BinblogDeviceDataSource source;
  const BinblogPirTriggerActionRepository(this.source);

  String _path(String chipId, [String suffix = '']) {
    if (chipId.isEmpty) {
      throw const PirTriggerFailure(
        PirTriggerFailureKind.unavailable,
        'PIR chưa có mã chip.',
        code: 'source_not_found',
      );
    }
    return 'api/devices/${Uri.encodeComponent(chipId)}/trigger_actions$suffix';
  }

  @override
  Future<PirTriggerConfiguration> loadConfiguration(String chipId) async {
    try {
      return configurationFromJson(await source.getJson(_path(chipId)));
    } on PirTriggerFailure {
      rethrow;
    } on BinblogApiException catch (error) {
      throw _readFailure(error);
    } catch (_) {
      throw const PirTriggerFailure(
        PirTriggerFailureKind.connection,
        'Không tải được cấu hình hành động.',
      );
    }
  }

  @override
  Future<List<PirTriggerTarget>> loadTargets(String chipId) async {
    try {
      return targetsFromJson(await source.getJson(_path(chipId, '/targets')));
    } on PirTriggerFailure {
      rethrow;
    } on BinblogApiException catch (error) {
      throw _readFailure(error);
    } catch (_) {
      throw const PirTriggerFailure(
        PirTriggerFailureKind.connection,
        'Không tải được danh sách target.',
      );
    }
  }

  @override
  Future<void> create(String chipId, PirTriggerActionDraft draft) async {
    if (draft.targetId <= 0 || draft.relayIndex < 0 || draft.durationMs <= 0) {
      throw const PirTriggerFailure(
        PirTriggerFailureKind.rejected,
        'Cấu hình hành động không hợp lệ.',
        code: 'invalid_action',
      );
    }
    try {
      final response = await source.postJson(
        _path(chipId),
        body: _body(draft),
        successStatusCodes: const {201},
      );
      _validateActionReceipt(response, draft, null);
    } on PirTriggerFailure catch (error) {
      if (error.kind == PirTriggerFailureKind.invalidResponse) throw _uncertain;
      rethrow;
    } on BinblogApiException catch (error) {
      throw _mutationFailure(error);
    } catch (_) {
      throw _uncertain;
    }
  }

  @override
  Future<void> update(
    String chipId,
    int actionId,
    PirTriggerActionDraft draft,
  ) async {
    if (actionId <= 0) {
      throw const PirTriggerFailure(
        PirTriggerFailureKind.rejected,
        'Hành động không hợp lệ.',
        code: 'invalid_action',
      );
    }
    try {
      final response = await source.putJson(
        _path(chipId, '/$actionId'),
        body: _body(draft),
      );
      _validateActionReceipt(response, draft, actionId);
    } on PirTriggerFailure catch (error) {
      if (error.kind == PirTriggerFailureKind.invalidResponse) throw _uncertain;
      rethrow;
    } on BinblogApiException catch (error) {
      throw _mutationFailure(error);
    } catch (_) {
      throw _uncertain;
    }
  }

  @override
  Future<void> delete(String chipId, int actionId) async {
    try {
      final response = await source.deleteJson(_path(chipId, '/$actionId'));
      if (response['status'] != 'success' ||
          response['action_id'] != actionId) {
        throw _uncertain;
      }
    } on PirTriggerFailure catch (error) {
      if (error.kind == PirTriggerFailureKind.invalidResponse) throw _uncertain;
      rethrow;
    } on BinblogApiException catch (error) {
      throw _mutationFailure(error);
    } catch (_) {
      throw _uncertain;
    }
  }

  @override
  Future<void> reorder(String chipId, List<int> actionIds) async {
    if (actionIds.isEmpty ||
        actionIds.toSet().length != actionIds.length ||
        actionIds.any((id) => id <= 0)) {
      throw const PirTriggerFailure(
        PirTriggerFailureKind.rejected,
        'Thứ tự hành động không hợp lệ.',
        code: 'invalid_order',
      );
    }
    try {
      final response = await source.putJson(
        _path(chipId, '/order'),
        body: jsonEncode({'action_ids': actionIds}),
      );
      final rows = response['actions'];
      if (response['status'] != 'success' || rows is! List) throw _uncertain;
      final received = rows
          .map(actionFromJson)
          .map((action) => action.id)
          .toList();
      if (received.length != actionIds.length ||
          !List.generate(
            actionIds.length,
            (i) => received[i] == actionIds[i],
          ).every((value) => value)) {
        throw _uncertain;
      }
    } on PirTriggerFailure catch (error) {
      if (error.kind == PirTriggerFailureKind.invalidResponse) throw _uncertain;
      rethrow;
    } on BinblogApiException catch (error) {
      throw _mutationFailure(error);
    } catch (_) {
      throw _uncertain;
    }
  }

  @override
  Future<void> migrateLegacy(String chipId) async {
    try {
      final response = await source.postJson(_path(chipId, '/migrate_legacy'));
      final action = actionFromJson(response['action']);
      if (response['status'] != 'success' ||
          response['mode'] != 'actions' ||
          action.origin != PirTriggerActionOrigin.persisted ||
          action.id == null) {
        throw _uncertain;
      }
    } on PirTriggerFailure catch (error) {
      if (error.kind == PirTriggerFailureKind.invalidResponse) throw _uncertain;
      rethrow;
    } on BinblogApiException catch (error) {
      throw _mutationFailure(error);
    } catch (_) {
      throw _uncertain;
    }
  }

  String _body(PirTriggerActionDraft draft) => jsonEncode({
    'target_device_id': draft.targetId,
    'action_type': 'relay_pulse',
    'relay_index': draft.relayIndex,
    'duration_ms': draft.durationMs,
    'delay_ms': 0,
    'enabled': draft.enabled,
  });

  void _validateActionReceipt(
    Map<String, dynamic> response,
    PirTriggerActionDraft draft,
    int? expectedId,
  ) {
    final action = actionFromJson(response['action']);
    if (response['status'] != 'success' ||
        action.origin != PirTriggerActionOrigin.persisted ||
        action.id == null ||
        expectedId != null && action.id != expectedId ||
        action.target?.id != draft.targetId ||
        action.relayIndex != draft.relayIndex ||
        action.durationMs != draft.durationMs ||
        action.delayMs != 0 ||
        action.enabled != draft.enabled) {
      throw _uncertain;
    }
  }

  PirTriggerFailure _readFailure(BinblogApiException error) =>
      switch (error.statusCode) {
        401 => const PirTriggerFailure(
          PirTriggerFailureKind.authentication,
          'Phiên đăng nhập không còn hợp lệ.',
        ),
        404 => PirTriggerFailure(
          PirTriggerFailureKind.unavailable,
          error.message,
          code: error.code,
        ),
        503 when error.code == 'feature_disabled' => PirTriggerFailure(
          PirTriggerFailureKind.featureDisabled,
          error.message,
          code: error.code,
        ),
        _ => PirTriggerFailure(
          PirTriggerFailureKind.connection,
          error.message,
          code: error.code,
        ),
      };

  PirTriggerFailure _mutationFailure(BinblogApiException error) =>
      switch (error.statusCode) {
        401 => const PirTriggerFailure(
          PirTriggerFailureKind.authentication,
          'Phiên đăng nhập không còn hợp lệ.',
        ),
        404 => PirTriggerFailure(
          PirTriggerFailureKind.unavailable,
          error.message,
          code: error.code,
        ),
        409 || 422 => PirTriggerFailure(
          PirTriggerFailureKind.rejected,
          error.message,
          code: error.code,
        ),
        503 when error.code == 'feature_disabled' => PirTriggerFailure(
          PirTriggerFailureKind.featureDisabled,
          error.message,
          code: error.code,
        ),
        _ => _uncertain,
      };

  static const _uncertain = PirTriggerFailure(
    PirTriggerFailureKind.uncertainMutation,
    'Chưa xác nhận được kết quả cập nhật. Hãy tải lại trước khi chỉnh sửa tiếp.',
  );
}
