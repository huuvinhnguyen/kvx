import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../application/usecases/buzzer_usecases.dart';
import '../../domain/entities/buzzer_detail.dart';

class BuzzerProvider extends ChangeNotifier {
  final String deviceId;
  final BuzzerUseCases useCases;
  final DateTime Function() now;
  BuzzerDetail? detail;
  bool isLoading = false;
  BuzzerCommand? pendingCommand;
  String? errorMessage;
  String? notice;
  bool needsLogin = false;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;
  int _generation = 0;
  bool _disposed = false;

  BuzzerProvider({
    required this.deviceId,
    required this.useCases,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  bool get isBusy => isLoading || pendingCommand != null;
  int get cooldownSeconds =>
      ((_cooldownUntil?.difference(now()).inMilliseconds ?? 0) / 1000)
          .ceil()
          .clamp(0, 60);
  bool _current(int request) => !_disposed && request == _generation;

  Future<void> load() async {
    if (_disposed || pendingCommand != null) return;
    final request = ++_generation;
    isLoading = true;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final result = await useCases.load(deviceId);
      if (!_current(request)) return;
      detail = result;
      needsLogin = false;
    } catch (error) {
      if (_current(request)) _handle(error);
    } finally {
      if (_current(request)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> send(BuzzerCommand command) async {
    if (_disposed || isBusy || needsLogin || detail == null) return;
    if (command == BuzzerCommand.test && cooldownSeconds > 0) return;
    final request = ++_generation;
    pendingCommand = command;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final receipt = await useCases.execute(detail!, command);
      if (!_current(request)) return;
      if (command == BuzzerCommand.test) _cooldown(receipt.cooldownSeconds);
      notice = 'Đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.';
      // Read only: failure here must never replay the command.
      final updated = await useCases.load(deviceId);
      if (_current(request)) detail = updated;
    } catch (error) {
      if (_current(request)) _handle(error);
    } finally {
      if (_current(request)) {
        pendingCommand = null;
        notifyListeners();
      }
    }
  }

  void _handle(Object error) {
    if (error is BuzzerFailure) {
      if (error.kind == BuzzerFailureKind.authentication) {
        needsLogin = true;
        detail = null;
        notice = null;
      }
      if (error.kind == BuzzerFailureKind.unavailable) {
        detail = null;
      }
      if (error.kind == BuzzerFailureKind.cooldown) {
        _cooldown(error.retryAfterSeconds);
      }
    }
    errorMessage = error.toString();
  }

  void _cooldown(int seconds) {
    _cooldownUntil = now().add(Duration(seconds: seconds));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || cooldownSeconds == 0) timer.cancel();
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
