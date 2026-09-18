import '../entities/buzzer_detail.dart';

abstract class BuzzerRepository {
  Future<BuzzerDetail> load(String deviceId);
  Future<BuzzerCommandReceipt> send(String deviceId, BuzzerCommand command);
}
