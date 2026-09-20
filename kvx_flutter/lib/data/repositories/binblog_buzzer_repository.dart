import '../../domain/entities/buzzer_detail.dart';
import '../../domain/repositories/buzzer_repository.dart';
import '../datasources/binblog_device_datasource.dart';
import '../models/buzzer_detail_dto.dart';

class BinblogBuzzerRepository implements BuzzerRepository {
  final BinblogDeviceDataSource source;
  const BinblogBuzzerRepository(this.source);

  String _path(String id, [String suffix = '']) {
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      throw const BuzzerFailure(BuzzerFailureKind.unavailable);
    }
    return 'api/devices/$id/buzzer$suffix';
  }

  @override
  Future<BuzzerDetail> load(String deviceId) async {
    try {
      return BuzzerDetailDto.fromDetailJson(await source.getJson(_path(deviceId)));
    } on BuzzerFailure {
      rethrow;
    } on BinblogApiException catch (error) {
      throw _failure(error, mutation: false);
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.connection);
    }
  }

  @override
  Future<List<BuzzerSource>> loadLinkedPirs(String deviceId) async {
    try {
      return BuzzerDetailDto.sourcesFromJson(
        await source.getJson(_path(deviceId, '/linked_pirs')),
      );
    } on BuzzerFailure {
      rethrow;
    } on BinblogApiException catch (error) {
      throw _failure(error, mutation: false);
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.connection);
    }
  }

  @override
  Future<List<BuzzerMotionEvent>> loadHistory(String deviceId) async {
    try {
      return BuzzerDetailDto.eventsFromJson(
        await source.getJson(_path(deviceId, '/history')),
      );
    } on BuzzerFailure {
      rethrow;
    } on BinblogApiException catch (error) {
      throw _failure(error, mutation: false);
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.connection);
    }
  }

  @override
  Future<BuzzerTestReceipt> test(String deviceId) async {
    try {
      final json = await source.postJson(_path(deviceId, '/test'));
      if (json['status'] != 'success' || json['message'] is! String) {
        throw const BuzzerFailure(BuzzerFailureKind.command);
      }
      return BuzzerTestReceipt(
        message: json['message'] as String,
        relayIndex: json['relay_index'] as int?,
        longlast: json['longlast'] as int?,
      );
    } on BuzzerFailure {
      rethrow;
    } on BinblogApiException catch (error) {
      throw _failure(error, mutation: true);
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.command);
    }
  }

  BuzzerFailure _failure(BinblogApiException error, {required bool mutation}) =>
      switch (error.statusCode) {
        401 => const BuzzerFailure(BuzzerFailureKind.authentication),
        404 => const BuzzerFailure(BuzzerFailureKind.unavailable),
        422 => const BuzzerFailure(BuzzerFailureKind.configuration),
        429 => BuzzerFailure(
          BuzzerFailureKind.cooldown,
          retryAfterSeconds: error.retryAfterSeconds,
        ),
        503 => const BuzzerFailure(BuzzerFailureKind.command),
        _ => BuzzerFailure(
          mutation ? BuzzerFailureKind.command : BuzzerFailureKind.connection,
        ),
      };
}
