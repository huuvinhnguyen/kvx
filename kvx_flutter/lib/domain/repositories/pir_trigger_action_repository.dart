import '../entities/pir_trigger_action.dart';

abstract interface class PirTriggerActionRepository {
  Future<PirTriggerConfiguration> loadConfiguration(String chipId);
  Future<List<PirTriggerTarget>> loadTargets(String chipId);
  Future<void> create(String chipId, PirTriggerActionDraft draft);
  Future<void> update(String chipId, int actionId, PirTriggerActionDraft draft);
  Future<void> delete(String chipId, int actionId);
  Future<void> reorder(String chipId, List<int> actionIds);
  Future<void> migrateLegacy(String chipId);
}
