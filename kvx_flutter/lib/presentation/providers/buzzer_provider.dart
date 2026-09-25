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
  List<AvailableBuzzerPir> availablePirs = const [];
  bool isLoadingAvailable = false;
  bool isMutating = false;
  bool requiresRefresh = false;
  bool _mutationSucceededAwaitingRefresh = false;
  String? availableError;
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
  bool get isBusy => isLoading || isTesting || isMutating;
  int get cooldownSeconds =>
      ((_cooldownUntil?.difference(now()).inMilliseconds ?? 0) / 1000)
          .ceil()
          .clamp(0, 60);
  bool _current(int request) => !_disposed && request == _generation;

  Future<void> load() async {
    if (_disposed || isTesting || isMutating) return;
    final reconciling = requiresRefresh;
    final request = ++_generation;
    isLoading = true;
    errorMessage = null;
    if (!requiresRefresh) notice = null;
    notifyListeners();
    try {
      final result = await useCases.load(deviceId);
      if (!_current(request)) return;
      if (requiresRefresh) {
        final available = await useCases.availablePirs(deviceId);
        if (!_current(request)) return;
        availablePirs = available;
      }
      detail = result.$1;
      sources = result.$2;
      events = result.$3;
      needsLogin = false;
      requiresRefresh = false;
      if (_mutationSucceededAwaitingRefresh) {
        notice =
            'Đã cập nhật cấu hình PIR. Liên kết không chạy Test Buzzer hoặc phát âm.';
      } else if (reconciling) {
        notice = 'Đã tải lại cấu hình PIR từ máy chủ.';
      }
      _mutationSucceededAwaitingRefresh = false;
    } catch (error) {
      if (_current(request)) {
        _handle(error);
        if (requiresRefresh) {
          errorMessage = _mutationSucceededAwaitingRefresh
              ? 'Đã cập nhật cấu hình PIR nhưng chưa tải lại được dữ liệu. Hãy tải lại trước khi chỉnh sửa tiếp. $error'
              : 'Chưa xác nhận được kết quả cập nhật cấu hình. Hãy tải lại trước khi chỉnh sửa tiếp. $error';
        }
      }
    } finally {
      if (_current(request)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAvailable() async {
    if (_disposed || isMutating) return;
    final request = _generation;
    isLoadingAvailable = true;
    availableError = null;
    notifyListeners();
    try {
      final values = await useCases.availablePirs(deviceId);
      if (_current(request)) availablePirs = values;
    } catch (error) {
      if (_current(request)) availableError = error.toString();
    } finally {
      if (_current(request)) {
        isLoadingAvailable = false;
        notifyListeners();
      }
    }
  }

  Future<void> link(BuzzerLinkConfiguration configuration) async {
    if (_disposed ||
        isBusy ||
        requiresRefresh ||
        !configuration.isValid ||
        !availablePirs.any((pir) => pir.id == configuration.pirId)) {
      return;
    }
    await _mutate(() => useCases.link(deviceId, configuration));
  }

  Future<void> unlink(String pirId) async {
    if (_disposed ||
        isBusy ||
        requiresRefresh ||
        !sources.any((pir) => pir.id == pirId)) {
      return;
    }
    await _mutate(() => useCases.unlink(deviceId, pirId));
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    final request = ++_generation;
    isMutating = true;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      await operation();
      if (!_current(request)) return;
    } catch (error) {
      if (_current(request)) {
        if (error is BuzzerFailure &&
            error.kind == BuzzerFailureKind.uncertainMutation) {
          requiresRefresh = true;
          _mutationSucceededAwaitingRefresh = false;
          errorMessage = error.toString();
        } else {
          _handle(error);
        }
        isMutating = false;
        notifyListeners();
      }
      return;
    }
    _mutationSucceededAwaitingRefresh = true;
    notice = 'Đã cập nhật cấu hình PIR. Đang tải lại danh sách…';
    notifyListeners();
    try {
      final result = await Future.wait<Object>([
        useCases.load(deviceId),
        useCases.availablePirs(deviceId),
      ]);
      if (!_current(request)) return;
      final loaded =
          result[0]
              as (BuzzerDetail, List<BuzzerSource>, List<BuzzerMotionEvent>);
      detail = loaded.$1;
      sources = loaded.$2;
      events = loaded.$3;
      availablePirs = result[1] as List<AvailableBuzzerPir>;
      requiresRefresh = false;
      _mutationSucceededAwaitingRefresh = false;
      notice =
          'Đã cập nhật cấu hình PIR. Liên kết không chạy Test Buzzer hoặc phát âm.';
    } catch (error) {
      if (!_current(request)) return;
      requiresRefresh = true;
      errorMessage =
          'Đã cập nhật cấu hình PIR nhưng chưa tải lại được dữ liệu. Hãy tải lại trước khi chỉnh sửa tiếp. $error';
    } finally {
      if (_current(request)) {
        isMutating = false;
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
