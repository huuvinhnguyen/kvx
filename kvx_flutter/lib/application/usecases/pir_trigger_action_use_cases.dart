import '../../domain/entities/pir_trigger_action.dart';
import '../../domain/repositories/pir_trigger_action_repository.dart';

class PirTriggerActionUseCases {
  final PirTriggerActionRepository repository;
  const PirTriggerActionUseCases(this.repository);

  Future<PirTriggerSnapshot> load(String chipId) async {
    final values = await Future.wait<Object>([
      repository.loadConfiguration(chipId),
      repository.loadTargets(chipId),
    ]);
    return PirTriggerSnapshot(
      values[0] as PirTriggerConfiguration,
      values[1] as List<PirTriggerTarget>,
    );
  }

  Future<void> create(String chipId, PirTriggerActionDraft draft) =>
      repository.create(chipId, draft);
  Future<void> update(String chipId, int id, PirTriggerActionDraft draft) =>
      repository.update(chipId, id, draft);
  Future<void> delete(String chipId, int id) => repository.delete(chipId, id);
  Future<void> reorder(String chipId, List<int> ids) =>
      repository.reorder(chipId, ids);
  Future<void> migrateLegacy(String chipId) => repository.migrateLegacy(chipId);
}
