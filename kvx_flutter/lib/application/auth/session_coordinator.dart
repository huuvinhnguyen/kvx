import 'dart:async';
import '../../domain/auth/session.dart';

class SessionCoordinator implements SessionAccess {
  final SessionStore _store;
  final PasswordAuthenticator _authentication;
  final _changes = StreamController<SessionState>.broadcast(sync: true);
  SessionState _state = const SessionState();
  String? _token;
  int _revision = 0;
  Future<void> _tail = Future.value();
  bool _disposed = false;

  SessionCoordinator({
    required SessionStore store,
    required PasswordAuthenticator authentication,
  }) : _store = store,
       _authentication = authentication;
  SessionState get state => _state;
  Stream<SessionState> get changes => _changes.stream;
  void _publish(SessionState value) {
    _state = value;
    if (!_disposed) _changes.add(value);
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool _currentIntent(int intent) => !_disposed && intent == _revision;

  Future<void> restore() async {
    if (_disposed ||
        !(_state.phase == SessionPhase.unknown ||
            _state.phase == SessionPhase.restoring && _state.message != null)) {
      return;
    }
    final intent = ++_revision;
    _publish(
      SessionState(
        phase: SessionPhase.restoring,
        generation: _state.generation,
      ),
    );
    try {
      final stored = await _serialized(_store.read);
      if (!_currentIntent(intent)) return;
      final token = stored?.token;
      if (token != null) {
        if (token.trim().isEmpty) {
          throw const SessionFailure(SessionFailureKind.invalidToken);
        }
        _token = token;
        _publish(
          SessionState(
            phase: SessionPhase.authenticated,
            generation: _state.generation + 1,
          ),
        );
      } else {
        _publish(
          SessionState(
            phase: SessionPhase.signedOut,
            generation: _state.generation,
          ),
        );
      }
    } catch (_) {
      if (_currentIntent(intent)) {
        _publish(
          SessionState(
            phase: SessionPhase.restoring,
            generation: _state.generation,
            message: 'Không đọc được phiên đã lưu. Hãy thử lại hoặc đăng xuất.',
          ),
        );
      }
    }
  }

  Future<void> login(String username, String password) =>
      authenticate(() => _authentication.login(username, password));

  // Provider exchanges can return a Binblog candidate through the same explicit
  // authentication intent; provider credentials are never persisted here.
  Future<void> authenticate(Future<String> Function() exchange) async {
    if (_disposed ||
        _state.phase != SessionPhase.signedOut ||
        _state.clearing ||
        _state.message != null) {
      throw const SessionFailure(SessionFailureKind.signedOut);
    }
    final intent = ++_revision;
    _publish(
      SessionState(
        phase: SessionPhase.authenticating,
        generation: _state.generation,
      ),
    );
    try {
      final candidate = await exchange();
      if (!_currentIntent(intent)) {
        throw const SessionFailure(SessionFailureKind.stale);
      }
      if (candidate.trim().isEmpty) {
        throw const SessionFailure(SessionFailureKind.invalidToken);
      }
      try {
        await _serialized(() => _store.write(StoredSession.active(candidate)));
      } catch (_) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      if (!_currentIntent(intent)) {
        throw const SessionFailure(SessionFailureKind.stale);
      }
      _token = candidate;
      _publish(
        SessionState(
          phase: SessionPhase.authenticated,
          generation: _state.generation + 1,
        ),
      );
    } catch (error) {
      if (!_currentIntent(intent)) {
        throw const SessionFailure(SessionFailureKind.stale);
      }
      final failure =
          error is SessionFailure || error is AuthenticationAttemptFailure
          ? error
          : const SessionFailure(SessionFailureKind.login);
      _publish(
        SessionState(
          phase: SessionPhase.signedOut,
          generation: _state.generation,
          message:
              failure is SessionFailure &&
                  failure.kind == SessionFailureKind.storage
              ? failure.toString()
              : null,
        ),
      );
      throw failure;
    }
  }

  Future<bool> logout({SignOutReason reason = SignOutReason.logout}) async {
    if (_disposed) return false;
    final intent = ++_revision;
    _token = null;
    final generation = _state.generation + 1;
    _publish(
      SessionState(
        phase: SessionPhase.signedOut,
        generation: generation,
        reason: reason,
        clearing: true,
      ),
    );
    try {
      await _serialized(() async {
        try {
          await _store.write(const StoredSession.signedOut());
        } catch (_) {
          await _store.delete();
        }
      });
      if (!_currentIntent(intent)) return false;
      _publish(
        SessionState(
          phase: SessionPhase.signedOut,
          generation: generation,
          reason: reason,
        ),
      );
      return true;
    } catch (_) {
      if (_currentIntent(intent)) {
        _publish(
          SessionState(
            phase: SessionPhase.signedOut,
            generation: generation,
            reason: reason,
            message: const SessionFailure(
              SessionFailureKind.storage,
            ).toString(),
          ),
        );
      }
      return false;
    }
  }

  Future<void> switchAccount(String username, String password) async {
    if (!await logout(reason: SignOutReason.switching)) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    await login(username, password);
  }

  @override
  SessionSnapshot snapshot({int? expectedGeneration}) {
    if (_disposed ||
        _state.phase != SessionPhase.authenticated ||
        _token == null) {
      throw const SessionFailure(SessionFailureKind.signedOut);
    }
    if (expectedGeneration != null && expectedGeneration != _state.generation) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return SessionSnapshot(_token!, _state.generation);
  }

  @override
  bool isCurrent(int generation) =>
      !_disposed &&
      _state.phase == SessionPhase.authenticated &&
      generation == _state.generation;
  @override
  Future<T> dispatch<T>(int generation, Future<T> Function() start) {
    if (!isCurrent(generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return start(); // No await between generation check and transport submission.
  }

  @override
  Future<bool> unauthorized(int generation) async {
    if (!isCurrent(generation)) return false;
    await logout(reason: SignOutReason.expired);
    return true;
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _token = null;
    _changes.close();
  }
}
