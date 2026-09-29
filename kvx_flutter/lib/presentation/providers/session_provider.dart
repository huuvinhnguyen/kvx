import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../application/auth/session_coordinator.dart';
import '../../domain/auth/session.dart';

class SessionProvider extends ChangeNotifier {
  final SessionCoordinator coordinator;
  late final StreamSubscription<SessionState> _subscription;
  bool _disposed = false;
  String? loginError;
  SessionState get state => coordinator.state;
  SessionProvider(this.coordinator) {
    _subscription = coordinator.changes.listen((_) {
      if (!_disposed) notifyListeners();
    });
  }
  Future<void> restore() => coordinator.restore();
  Future<void> login(String username, String password) async {
    loginError = null;
    if (!_disposed) notifyListeners();
    try {
      await coordinator.login(username.trim(), password);
    } on SessionFailure catch (error) {
      if (error.kind != SessionFailureKind.stale) loginError = error.toString();
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> logout({SignOutReason reason = SignOutReason.logout}) {
    loginError = null;
    return coordinator.logout(reason: reason);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
