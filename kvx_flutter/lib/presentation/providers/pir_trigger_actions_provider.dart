import 'package:flutter/foundation.dart';
import '../../application/usecases/pir_trigger_action_use_cases.dart';
import '../../domain/entities/pir_trigger_action.dart';

enum PirTriggerPhase {
  idle,
  loading,
  ready,
  legacy,
  invalidLegacy,
  mutating,
  reconciling,
  uncertain,
  failed,
  featureDisabled,
}

class PirTriggerActionsProvider extends ChangeNotifier {
  final String chipId;
  final PirTriggerActionUseCases useCases;
  PirTriggerPhase phase = PirTriggerPhase.idle;
  PirTriggerSnapshot? snapshot;
  String? errorMessage;
  String? notice;
  bool needsLogin = false;
  int _generation = 0;
  bool _disposed = false;
  bool _mutationInFlight = false;

  PirTriggerActionsProvider({required this.chipId, required this.useCases});
  List<PirTriggerAction> get actions =>
      snapshot?.configuration.actions ?? const [];
  List<PirTriggerTarget> get targets => snapshot?.targets ?? const [];
  bool get isBusy => {
    PirTriggerPhase.loading,
    PirTriggerPhase.mutating,
    PirTriggerPhase.reconciling,
  }.contains(phase);
  bool get canManage =>
      phase == PirTriggerPhase.ready &&
      snapshot?.configuration.mode == PirTriggerConfigurationMode.actions;
  bool get canAdd =>
      phase == PirTriggerPhase.ready &&
      {
        PirTriggerConfigurationMode.empty,
        PirTriggerConfigurationMode.actions,
      }.contains(snapshot?.configuration.mode);
  bool get canMigrateLegacy {
    if (phase != PirTriggerPhase.legacy ||
        actions.length != 1 ||
        actions.single.origin != PirTriggerActionOrigin.legacy) {
      return false;
    }
    final target = actions.single.target;
    return target != null && targets.any((value) => value.id == target.id);
  }

  List<PirTriggerTarget> get availableTargetsForAdd {
    final used = actions
        .map((action) => action.target?.id)
        .whereType<int>()
        .toSet();
    return targets
        .where((target) => !used.contains(target.id))
        .toList(growable: false);
  }

  bool _current(int request) => !_disposed && request == _generation;

  Future<void> load() async {
    if (_disposed || _mutationInFlight) return;
    final wasUncertain = phase == PirTriggerPhase.uncertain;
    final request = ++_generation;
    phase = wasUncertain
        ? PirTriggerPhase.reconciling
        : PirTriggerPhase.loading;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final loaded = await useCases.load(chipId);
      if (!_current(request)) return;
      _apply(loaded);
      needsLogin = false;
    } catch (error) {
      if (!_current(request)) return;
      _handleLoadFailure(error, uncertain: wasUncertain);
    }
    if (_current(request)) notifyListeners();
  }

  Future<void> create(PirTriggerActionDraft draft) async {
    if (!canAdd ||
        !availableTargetsForAdd.any((target) => target.id == draft.targetId) ||
        !draft.isValid(targets)) {
      return;
    }
    await _mutate(() => useCases.create(chipId, draft), 'Đã thêm hành động.');
  }

  Future<void> update(
    PirTriggerAction action,
    PirTriggerActionDraft draft,
  ) async {
    if (!canManage || action.id == null || !draft.isValid(targets)) return;
    await _mutate(
      () => useCases.update(chipId, action.id!, draft),
      'Đã cập nhật hành động.',
    );
  }

  Future<void> delete(PirTriggerAction action) async {
    if (!canManage || action.id == null) return;
    await _mutate(
      () => useCases.delete(chipId, action.id!),
      'Đã xóa hành động.',
    );
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (!canManage) return;
    final values = [...actions];
    if (newIndex > oldIndex) newIndex--;
    final moved = values.removeAt(oldIndex);
    values.insert(newIndex, moved);
    final ids = values.map((action) => action.id).whereType<int>().toList();
    if (ids.length != values.length ||
        ids.toSet().length != ids.length ||
        _same(
          ids,
          actions.map((action) => action.id).whereType<int>().toList(),
        )) {
      return;
    }
    await _mutate(
      () => useCases.reorder(chipId, ids),
      'Đã cập nhật thứ tự hành động.',
    );
  }

  Future<void> migrateLegacy() async {
    if (!canMigrateLegacy) return;
    await _mutate(
      () => useCases.migrateLegacy(chipId),
      'Đã chuyển cấu hình cũ sang danh sách hành động.',
    );
  }

  Future<void> _mutate(
    Future<void> Function() operation,
    String successMessage,
  ) async {
    if (_disposed || _mutationInFlight || isBusy) return;
    _mutationInFlight = true;
    final request = ++_generation;
    phase = PirTriggerPhase.mutating;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      await operation();
      if (!_current(request)) {
        _mutationInFlight = false;
        return;
      }
      await _reconcile(request, successMessage: successMessage);
    } on PirTriggerFailure catch (error) {
      if (!_current(request)) {
        _mutationInFlight = false;
        return;
      }
      switch (error.kind) {
        case PirTriggerFailureKind.authentication:
          needsLogin = true;
          phase = PirTriggerPhase.failed;
          errorMessage = error.message;
          _mutationInFlight = false;
        case PirTriggerFailureKind.featureDisabled:
          phase = PirTriggerPhase.featureDisabled;
          errorMessage = error.message;
          _mutationInFlight = false;
        case PirTriggerFailureKind.uncertainMutation ||
            PirTriggerFailureKind.connection ||
            PirTriggerFailureKind.invalidResponse:
          phase = PirTriggerPhase.uncertain;
          errorMessage = error.message;
          notifyListeners();
          await _reconcile(
            request,
            successMessage:
                'Đã tải lại trạng thái máy chủ sau kết quả chưa xác định.',
            uncertainOutcome: true,
          );
        case PirTriggerFailureKind.rejected ||
            PirTriggerFailureKind.unavailable:
          await _reconcile(request, preservedError: error.message);
      }
    } catch (_) {
      if (!_current(request)) {
        _mutationInFlight = false;
        return;
      }
      phase = PirTriggerPhase.uncertain;
      errorMessage =
          'Chưa xác nhận được kết quả cập nhật. Hãy tải lại trước khi chỉnh sửa tiếp.';
      notifyListeners();
      await _reconcile(
        request,
        successMessage:
            'Đã tải lại trạng thái máy chủ sau kết quả chưa xác định.',
        uncertainOutcome: true,
      );
    }
    if (_current(request)) notifyListeners();
  }

  Future<void> _reconcile(
    int request, {
    String? successMessage,
    String? preservedError,
    bool uncertainOutcome = false,
  }) async {
    phase = PirTriggerPhase.reconciling;
    notifyListeners();
    try {
      final loaded = await useCases.load(chipId);
      if (!_current(request)) {
        _mutationInFlight = false;
        return;
      }
      _apply(loaded);
      errorMessage = preservedError;
      notice = successMessage;
      needsLogin = false;
    } catch (error) {
      if (!_current(request)) {
        _mutationInFlight = false;
        return;
      }
      if (error is PirTriggerFailure &&
          error.kind == PirTriggerFailureKind.authentication) {
        needsLogin = true;
        phase = PirTriggerPhase.failed;
      } else if (error is PirTriggerFailure &&
          error.kind == PirTriggerFailureKind.featureDisabled) {
        phase = PirTriggerPhase.featureDisabled;
      } else {
        phase = PirTriggerPhase.uncertain;
      }
      errorMessage =
          '${uncertainOutcome ? 'Chưa xác nhận được kết quả cập nhật. ' : 'Đã gửi cập nhật nhưng chưa tải lại được trạng thái. '}$error';
    }
    _mutationInFlight = false;
  }

  void _apply(PirTriggerSnapshot loaded) {
    snapshot = loaded;
    phase = switch (loaded.configuration.mode) {
      PirTriggerConfigurationMode.empty ||
      PirTriggerConfigurationMode.actions => PirTriggerPhase.ready,
      PirTriggerConfigurationMode.legacy => PirTriggerPhase.legacy,
      PirTriggerConfigurationMode.invalidLegacy =>
        PirTriggerPhase.invalidLegacy,
    };
  }

  void _handleLoadFailure(Object error, {required bool uncertain}) {
    errorMessage = error.toString();
    if (error is PirTriggerFailure &&
        error.kind == PirTriggerFailureKind.authentication) {
      needsLogin = true;
      phase = PirTriggerPhase.failed;
    } else if (error is PirTriggerFailure &&
        error.kind == PirTriggerFailureKind.featureDisabled) {
      phase = PirTriggerPhase.featureDisabled;
    } else {
      phase = uncertain ? PirTriggerPhase.uncertain : PirTriggerPhase.failed;
    }
  }

  bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((value) => value);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
