import '../entities/switch_detail.dart';

abstract class SwitchRepository {
  Future<SwitchDetail> detail(String id);
  Future<SwitchReminderPage> reminders(String id, int relay, {String? afterId});
  Future<SwitchStatistics> statistics(String id, int relay);
  Future<void> state(String id, int relay, int value);
  Future<void> pulse(String id, int relay, int durationMs);
  Future<void> refresh(String id);
}
