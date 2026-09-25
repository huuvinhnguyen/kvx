import '../entities/buzzer_detail.dart';

abstract class BuzzerRepository {
  Future<BuzzerDetail> load(String deviceId);
  Future<List<BuzzerSource>> loadLinkedPirs(String deviceId);
  Future<List<BuzzerMotionEvent>> loadHistory(String deviceId);
  Future<List<AvailableBuzzerPir>> loadAvailablePirs(String deviceId);
  Future<void> link(String deviceId, BuzzerLinkConfiguration configuration);
  Future<void> unlink(String deviceId, String pirId);
  Future<BuzzerTestReceipt> test(String deviceId);
}
