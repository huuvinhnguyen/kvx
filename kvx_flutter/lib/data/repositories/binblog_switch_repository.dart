import 'dart:convert';
import '../../domain/entities/switch_detail.dart';
import '../../domain/auth/session.dart';
import '../../domain/repositories/switch_repository.dart';
import '../datasources/binblog_device_datasource.dart';
import '../models/switch_dto.dart';

class BinblogSwitchRepository implements SwitchRepository {
  final BinblogDeviceDataSource source;
  const BinblogSwitchRepository(this.source);
  String _path(String id, [int? relay, String suffix = '']) {
    if (!SwitchDto.id(id) || relay != null && (relay < 0 || relay > 31)) {
      throw const SwitchFailure(SwitchFailureKind.validation);
    }
    return 'api/switches/$id${relay == null ? '' : '/relays/$relay'}$suffix';
  }

  Future<T> _read<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SessionFailure {
      rethrow;
    } on SwitchFailure {
      rethrow;
    } on BinblogApiException catch (e) {
      throw _failure(e, false);
    } on FormatException {
      throw const SwitchFailure(SwitchFailureKind.invalidData);
    } on TypeError {
      throw const SwitchFailure(SwitchFailureKind.invalidData);
    } catch (_) {
      throw const SwitchFailure(SwitchFailureKind.connection);
    }
  }

  SwitchFailure _failure(BinblogApiException e, bool mutation) =>
      SwitchFailure(switch (e.statusCode) {
        401 => SwitchFailureKind.authentication,
        403 || 404 => SwitchFailureKind.unavailable,
        400 || 406 || 413 || 415 || 422 => SwitchFailureKind.validation,
        503
            when e.code == 'feature_unavailable' ||
                e.code == 'command_unavailable' =>
          SwitchFailureKind.unavailable,
        _ =>
          mutation ? SwitchFailureKind.uncertain : SwitchFailureKind.connection,
      });
  @override
  Future<SwitchDetail> detail(String id) =>
      _read(() async => SwitchDto.detail(await source.getJson(_path(id))));
  @override
  Future<SwitchReminderPage> reminders(
    String id,
    int relay, {
    String? afterId,
  }) => _read(
    () async => SwitchDto.reminders(
      await source.getJson(_path(id, relay, '/reminders'), {
        'limit': '100',
        'after_id': ?afterId,
      }),
      id,
      relay,
      afterId,
    ),
  );
  @override
  Future<SwitchStatistics> statistics(String id, int relay) => _read(
    () async => SwitchDto.statistics(
      await source.getJson(_path(id, relay, '/statistics')),
    ),
  );
  Future<void> _command(String path, Map<String, Object>? body) async {
    try {
      final r = await source.postJson(
        path,
        body: body == null ? null : jsonEncode(body),
      );
      if (r['status'] != 'accepted' ||
          r['outcome'] != 'publish_returned' ||
          r['acknowledgement'] != 'none' ||
          r['request_id'] is! String ||
          !SwitchDto.id(r['event_id'])) {
        throw const SwitchFailure(SwitchFailureKind.uncertain);
      }
    } on SessionFailure {
      rethrow;
    } on SwitchFailure {
      rethrow;
    } on BinblogApiException catch (e) {
      throw _failure(e, true);
    } catch (_) {
      throw const SwitchFailure(SwitchFailureKind.uncertain);
    }
  }

  @override
  Future<void> state(String id, int relay, int value) {
    if (value != 0 && value != 1) {
      throw const SwitchFailure(SwitchFailureKind.validation);
    }
    return _command(_path(id, relay, '/state'), {'switch_value': value});
  }

  @override
  Future<void> pulse(String id, int relay, int durationMs) {
    if (durationMs < 1000 || durationMs > 86400000 || durationMs % 1000 != 0) {
      throw const SwitchFailure(SwitchFailureKind.validation);
    }
    return _command(_path(id, relay, '/pulse'), {'duration_ms': durationMs});
  }

  @override
  Future<void> refresh(String id) => _command('${_path(id)}/refresh', null);
}
