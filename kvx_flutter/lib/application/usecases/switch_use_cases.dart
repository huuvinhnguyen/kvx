import '../../domain/entities/switch_detail.dart';
import '../../domain/repositories/switch_repository.dart';

class SwitchUseCases {
  final SwitchRepository repository;
  final SwitchCommandContinuity continuity;
  SwitchUseCases(this.repository, {SwitchCommandContinuity? continuity})
    : continuity = continuity ?? SwitchCommandContinuity();
  Future<SwitchDetail> detail(String id) async {
    final value = await repository.detail(id);
    if (value.id != id) {
      throw const SwitchFailure(SwitchFailureKind.invalidData);
    }
    return value;
  }

  Future<SwitchReminderPage> reminders(
    String id,
    int relay, {
    String? afterId,
  }) => repository.reminders(id, relay, afterId: afterId);
  Future<SwitchStatistics> statistics(String id, int relay) =>
      repository.statistics(id, relay);
  Future<void> state(String id, int relay, int value) {
    if (value != 0 && value != 1) {
      throw const SwitchFailure(SwitchFailureKind.validation);
    }
    return _command(id, () => repository.state(id, relay, value));
  }

  Future<void> pulse(String id, int relay, int ms) {
    if (ms < 1000 || ms > 86400000 || ms % 1000 != 0) {
      throw const SwitchFailure(SwitchFailureKind.validation);
    }
    return _command(id, () => repository.pulse(id, relay, ms));
  }

  Future<void> refresh(String id) => _command(id, () => repository.refresh(id));
  Future<void> _command(String id, Future<void> Function() operation) async {
    if (!continuity.begin(id)) {
      throw const SwitchFailure(SwitchFailureKind.validation);
    }
    var unknown = true;
    try {
      await operation();
      unknown = false;
    } on SwitchFailure catch (e) {
      unknown = e.kind == SwitchFailureKind.uncertain;
      rethrow;
    } finally {
      continuity.finish(id, unknown: unknown);
    }
  }
}

// One instance per authenticated feature graph, shared across screen lifetimes.
class SwitchCommandContinuity {
  final _inFlight = <String>{};
  final _uncertain = <String>{};
  final _listeners = <void Function()>{};
  bool busy(String id) => _inFlight.contains(id);
  bool uncertain(String id) => _uncertain.contains(id);
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  bool begin(String id) {
    if (busy(id) || uncertain(id)) return false;
    _inFlight.add(id);
    _uncertain.add(id);
    _notify();
    return true;
  }

  void finish(String id, {required bool unknown}) {
    _inFlight.remove(id);
    if (!unknown) _uncertain.remove(id);
    _notify();
  }

  void reconcile(String id) {
    if (!busy(id)) {
      _uncertain.remove(id);
      _notify();
    }
  }
}
