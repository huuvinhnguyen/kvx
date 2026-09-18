import '../../domain/entities/buzzer_detail.dart';
import '../../domain/repositories/buzzer_repository.dart';
import '../datasources/binblog_device_datasource.dart';
import '../models/buzzer_detail_dto.dart';

class BinblogBuzzerRepository implements BuzzerRepository {
  final BinblogDeviceDataSource source;
  const BinblogBuzzerRepository(this.source);

  String _path(String id) {
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      throw const BuzzerFailure(BuzzerFailureKind.unavailable);
    }
    return 'api/buzzers/$id';
  }

  @override
  Future<BuzzerDetail> load(String deviceId) async {
    try {
      return BuzzerDetailDto.fromJson(
        await source.getJson(_path(deviceId), const {}),
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
  Future<BuzzerCommandReceipt> send(
    String deviceId,
    BuzzerCommand command,
  ) async {
    try {
      final action = command == BuzzerCommand.resetWifi
          ? 'reset_wifi'
          : command.name;
      final json = await source.postJson('${_path(deviceId)}/$action');
      final seconds =
          json['cooldown_seconds'] ?? (command == BuzzerCommand.test ? 3 : 0);
      if (json['status'] != 'accepted' ||
          json['acknowledgement'] != 'broker_only' ||
          seconds is! int ||
          seconds < 0 ||
          seconds > 60) {
        throw const BuzzerFailure(BuzzerFailureKind.command);
      }
      return BuzzerCommandReceipt(
        cooldownSeconds: command == BuzzerCommand.test
            ? seconds.clamp(3, 60)
            : 0,
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
        403 || 404 => const BuzzerFailure(BuzzerFailureKind.unavailable),
        422 => const BuzzerFailure(BuzzerFailureKind.configuration),
        429 => BuzzerFailure(
          BuzzerFailureKind.cooldown,
          retryAfterSeconds: error.retryAfterSeconds,
        ),
        _ => BuzzerFailure(
          mutation ? BuzzerFailureKind.command : BuzzerFailureKind.connection,
        ),
      };
}
