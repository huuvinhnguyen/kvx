import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../application/auth/session_coordinator.dart';
import '../../application/auth/google_sign_in_use_case.dart';
import '../../domain/auth/session.dart';

class SessionProvider extends ChangeNotifier {
  final SessionCoordinator coordinator;
  final GoogleSignInUseCase? googleSignIn;
  late final StreamSubscription<SessionState> _subscription;
  bool _disposed = false;
  bool _isSessionTransitioning = false;
  String? loginError;
  SessionState get state => coordinator.state;
  bool get isSessionTransitioning => _isSessionTransitioning;
  SessionProvider(this.coordinator, {this.googleSignIn}) {
    _subscription = coordinator.changes.listen((_) {
      if (!_disposed) notifyListeners();
    });
  }
  Future<void> restore() => coordinator.restore();
  Future<void> login(String username, String password) async {
    if (_disposed || _isSessionTransitioning) return;
    loginError = null;
    if (!_disposed) notifyListeners();
    try {
      await coordinator.login(username.trim(), password);
    } on SessionFailure catch (error) {
      if (error.kind != SessionFailureKind.stale) loginError = error.toString();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    if (_disposed || _isSessionTransitioning) return;
    loginError = null;
    if (!_disposed) notifyListeners();
    final useCase = googleSignIn;
    if (useCase == null) {
      loginError = const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.providerConfigurationFailure,
      ).toString();
    } else {
      try {
        await coordinator.authenticate(useCase.execute);
      } on SessionFailure catch (error) {
        if (error.kind != SessionFailureKind.stale) {
          loginError = error.toString();
        }
      } on AuthenticationAttemptFailure catch (error) {
        if (error.kind != AuthenticationAttemptFailureKind.userCancelled) {
          loginError = error.toString();
        }
      }
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> logout({SignOutReason reason = SignOutReason.logout}) async {
    if (_disposed || _isSessionTransitioning) return false;
    _isSessionTransitioning = true;
    loginError = null;
    notifyListeners();
    try {
      final completed = await coordinator.logout(reason: reason);
      if (completed) await googleSignIn?.signOut();
      return completed;
    } finally {
      _isSessionTransitioning = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
