import 'package:flutter/foundation.dart';
import '../../application/usecases/switch_use_cases.dart';
import '../../domain/entities/switch_detail.dart';

class SwitchProvider extends ChangeNotifier {
  final String deviceId;
  final SwitchUseCases useCases;
  SwitchProvider({required this.deviceId, required this.useCases}) {
    useCases.continuity.addListener(_continuityChanged);
  }
  void _continuityChanged() {
    if (!_disposed) notifyListeners();
  }

  bool get uncertain => useCases.continuity.uncertain(deviceId);
  bool get commandInFlight => useCases.continuity.busy(deviceId);
  SwitchDetail? detail;
  int? selectedRelay;
  List<SwitchReminder> reminders = const [];
  SwitchStatistics? statistics;
  String? nextAfterId, errorMessage, notice;
  bool isBusy = false, readReady = false;
  bool _disposed = false;
  int _generation = 0;
  bool get canCommand =>
      !_disposed &&
      !isBusy &&
      !commandInFlight &&
      readReady &&
      !uncertain &&
      detail != null;
  bool _current(int g) => !_disposed && g == _generation;

  Future<void> _relayData() async {
    final relay = selectedRelay;
    if (relay == null) return;
    final page = await useCases.reminders(deviceId, relay);
    final stats = detail!.statistics
        ? await useCases.statistics(deviceId, relay)
        : null;
    if (_disposed) return;
    reminders = page.reminders;
    nextAfterId = page.nextAfterId;
    statistics = stats;
  }

  Future<void> load() async {
    if (_disposed || isBusy) return;
    final g = ++_generation;
    isBusy = true;
    readReady = false;
    errorMessage = null;
    notifyListeners();
    try {
      final value = await useCases.detail(deviceId);
      if (!_current(g)) return;
      detail = value;
      if (!value.relays.any((r) => r.index == selectedRelay)) {
        selectedRelay = value.relays.firstOrNull?.index;
      }
      await _relayData();
      if (!_current(g)) return;
      readReady = true;
    } catch (e) {
      if (_current(g)) errorMessage = e.toString();
    } finally {
      if (_current(g)) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectRelay(int relay) async {
    if (_disposed ||
        isBusy ||
        detail == null ||
        !detail!.relays.any((r) => r.index == relay)) {
      return;
    }
    selectedRelay = relay;
    reminders = const [];
    statistics = null;
    nextAfterId = null;
    await load();
  }

  Future<void> moreReminders() async {
    final cursor = nextAfterId, relay = selectedRelay;
    if (_disposed || isBusy || cursor == null || relay == null || !readReady) {
      return;
    }
    final g = ++_generation;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await useCases.reminders(deviceId, relay, afterId: cursor);
      if (!_current(g)) return;
      reminders = List.unmodifiable([...reminders, ...page.reminders]);
      nextAfterId = page.nextAfterId;
    } catch (e) {
      if (_current(g)) errorMessage = e.toString();
    } finally {
      if (_current(g)) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  void acknowledgePhysicalCheck() {
    if (_disposed || isBusy || commandInFlight || !readReady) return;
    useCases.continuity.reconcile(deviceId);
    notice = 'Đã xác nhận kiểm tra thiết bị. Lệnh tiếp theo là yêu cầu mới.';
    notifyListeners();
  }

  Future<void> state(int value) async {
    final relay = selectedRelay;
    if (!canCommand || relay == null || !detail!.manualSwitch) return;
    await _command(() => useCases.state(deviceId, relay, value));
  }

  Future<void> pulse(int ms) async {
    final relay = selectedRelay;
    if (!canCommand || relay == null || !detail!.pulse) return;
    await _command(() => useCases.pulse(deviceId, relay, ms));
  }

  Future<void> refreshDevice() async {
    if (!canCommand || !detail!.refresh) return;
    await _command(() => useCases.refresh(deviceId));
  }

  Future<void> _command(Future<void> Function() operation) async {
    final g = ++_generation;
    isBusy = true;
    errorMessage = null;
    notice = null;
    notifyListeners();
    String? commandError;
    try {
      await operation();
      if (!_current(g)) return;
      notice =
          'Đã gửi lệnh; chưa xác nhận trạng thái vật lý. Dữ liệu dưới đây là snapshot máy chủ.';
    } catch (e) {
      if (!_current(g)) return;
      commandError = e.toString();
    } finally {
      if (_current(g)) {
        isBusy = false;
        notifyListeners();
      }
    }
    if (_current(g)) {
      await load();
      if (!_disposed && _generation == g + 1 && commandError != null) {
        errorMessage = [
          commandError,
          errorMessage,
        ].whereType<String>().join("\n");
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    useCases.continuity.removeListener(_continuityChanged);
    super.dispose();
  }
}
