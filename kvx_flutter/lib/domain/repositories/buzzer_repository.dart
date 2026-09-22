import '../entities/buzzer_detail.dart';

abstract class BuzzerRepository {
  Future<BuzzerDetail> load(String deviceId);
  Future<List<BuzzerSource>> loadLinkedPirs(String deviceId);
  Future<List<BuzzerMotionEvent>> loadHistory(String deviceId);
  Future<BuzzerTestReceipt> test(String deviceId);
}
