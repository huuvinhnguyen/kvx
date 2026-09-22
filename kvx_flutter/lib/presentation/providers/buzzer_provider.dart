import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../application/usecases/buzzer_usecases.dart';
import '../../domain/entities/buzzer_detail.dart';

class BuzzerProvider extends ChangeNotifier {
  final String deviceId;
  final BuzzerUseCases useCases;
  final DateTime Function() now;
  BuzzerDetail? detail;
  List<BuzzerSource> sources = const [];
  List<BuzzerMotionEvent> events = const [];
  bool isLoading = false;
  bool isTesting = false;
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
  bool get isBusy => isLoading || isTesting;
  int get cooldownSeconds =>
      ((_cooldownUntil?.difference(now()).inMilliseconds ?? 0) / 1000)
          .ceil()
          .clamp(0, 60);
  bool _current(int request) => !_disposed && request == _generation;

  Future<void> load() async {
    if (_disposed || isTesting) return;
    final request = ++_generation;
    isLoading = true;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final result = await useCases.load(deviceId);
      if (!_current(request)) return;
      detail = result.$1;
      sources = result.$2;
      events = result.$3;
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

  Future<void> test() async {
    if (_disposed ||
        isBusy ||
        needsLogin ||
        detail == null ||
        cooldownSeconds > 0) {
      return;
    }
    final request = ++_generation;
    isTesting = true;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final receipt = await useCases.test(deviceId);
      if (!_current(request)) return;
      _cooldown(3);
      notice = receipt.message.isEmpty
          ? 'Đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.'
          : receipt.message;
      final result = await useCases.load(deviceId);
      if (_current(request)) {
        detail = result.$1;
        sources = result.$2;
        events = result.$3;
      }
    } catch (error) {
      if (_current(request)) _handle(error);
    } finally {
      if (_current(request)) {
        isTesting = false;
        notifyListeners();
      }
    }
  }

  void _handle(Object error) {
    if (error is BuzzerFailure) {
      if (error.kind == BuzzerFailureKind.authentication) {
        needsLogin = true;
        detail = null;
        sources = const [];
        events = const [];
        notice = null;
      }
      if (error.kind == BuzzerFailureKind.unavailable) {
        detail = null;
        sources = const [];
        events = const [];
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
