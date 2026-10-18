import 'dart:async';
import '../../domain/auth/session.dart';

class SessionCoordinator implements SessionAccess, ReconciliationAccess {
  final SessionStore _store;
  final PasswordAuthenticator _authentication;
  final _changes = StreamController<SessionState>.broadcast(sync: true);
  SessionState _state = const SessionState();
  String? _token;
  ActiveSessionRecord? _record;
  int _revision = 0;
  String? _preparingId;
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

  void _setGate(ReconciliationGate gate) => _publish(
    SessionState(
      phase: _state.phase,
      generation: _state.generation,
      reason: _state.reason,
      message: _state.message,
      clearing: _state.clearing,
      reconciliation: gate,
    ),
  );

  static ReconciliationGate _gate(ReconciliationMarker? marker) =>
      switch (marker?.operation) {
        null => ReconciliationGate.clean,
        ReconciliationOperation.unlinkGoogle =>
          ReconciliationGate.pendingUnlink,
        ReconciliationOperation.rotateRecoveryCodes =>
          ReconciliationGate.pendingRotation,
      };

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
        _record = stored?.record;
        _publish(
          SessionState(
            phase: SessionPhase.authenticated,
            generation: _state.generation + 1,
            reconciliation: stored!.quarantined
                ? ReconciliationGate.corrupt
                : stored.record == null
                ? ReconciliationGate.legacy
                : _gate(stored.record!.marker),
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
      final installed = ActiveSessionRecord(candidate);
      try {
        await _serialized(() async {
          await _store.write(StoredSession.managed(installed));
          if ((await _store.read())?.record != installed) {
            throw const SessionFailure(SessionFailureKind.storage);
          }
        });
      } catch (_) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      if (!_currentIntent(intent)) {
        throw const SessionFailure(SessionFailureKind.stale);
      }
      _token = candidate;
      _record = installed;
      _publish(
        SessionState(
          phase: SessionPhase.authenticated,
          generation: _state.generation + 1,
          reconciliation: ReconciliationGate.clean,
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
    _record = null;
    _preparingId = null;
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
        if ((await _store.read())?.token != null) {
          throw const SessionFailure(SessionFailureKind.storage);
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

  @override
  ReconciliationGate reconciliationGate(int generation) {
    if (!isCurrent(generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return _state.reconciliation;
  }

  @override
  MutationLease? pendingMutation(int generation) {
    if (!isCurrent(generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    final record = _record;
    final marker = record?.marker;
    return record == null || marker == null
        ? null
        : MutationLease(generation, record.sessionId, marker);
  }

  @override
  Future<MutationLease> prepareMutation(
    ReconciliationOperation operation,
    int generation,
  ) async {
    final current = _record;
    if (!isCurrent(generation) ||
        _state.reconciliation != ReconciliationGate.clean ||
        current == null ||
        current.marker != null ||
        _preparingId != null) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    final intent = _revision;
    final marker = ReconciliationMarker(operation);
    _preparingId = marker.operationId;
    final updated = current.replacing(marker);
    final lease = MutationLease(generation, current.sessionId, marker);
    try {
      await _serialized(() async {
        if ((await _store.read())?.record != current) {
          throw const SessionFailure(SessionFailureKind.storage);
        }
        await _store.write(StoredSession.managed(updated));
        if ((await _store.read())?.record != updated) {
          throw const SessionFailure(SessionFailureKind.storage);
        }
      });
      if (!_currentIntent(intent) || !isCurrent(generation)) {
        throw const SessionFailure(SessionFailureKind.stale);
      }
      _record = updated;
      _setGate(_gate(marker));
      return lease;
    } catch (_) {
      if (_currentIntent(intent) &&
          isCurrent(generation) &&
          _state.reconciliation == ReconciliationGate.clean) {
        _setGate(ReconciliationGate.storageBlocked);
      }
      rethrow;
    } finally {
      if (_preparingId == marker.operationId) _preparingId = null;
    }
  }

  @override
  Future<T> dispatchPrepared<T>(
    MutationLease lease,
    Future<T> Function() start,
  ) {
    if (!isCurrent(lease.generation) ||
        _record?.sessionId != lease.sessionId ||
        _record?.marker != lease.marker ||
        _state.reconciliation != _gate(lease.marker)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return start();
  }

  @override
  Future<void> clearMutation(
    MutationLease lease,
    MarkerResolution resolution,
  ) async {
    final expected = _record;
    if (!isCurrent(lease.generation) ||
        expected?.sessionId != lease.sessionId ||
        expected?.marker != lease.marker) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    final allowed =
        resolution == MarkerResolution.provenNotDispatched ||
        (lease.marker.operation == ReconciliationOperation.unlinkGoogle &&
            (resolution == MarkerResolution.providerAbsent ||
                resolution == MarkerResolution.lastMethodRejected)) ||
        (lease.marker.operation ==
                ReconciliationOperation.rotateRecoveryCodes &&
            resolution == MarkerResolution.codesAcknowledged);
    if (!allowed) throw const SessionFailure(SessionFailureKind.storage);
    final intent = _revision;
    final clean = expected!.replacing(null);
    try {
      await _serialized(() async {
        if ((await _store.read())?.record != expected) {
          throw const SessionFailure(SessionFailureKind.storage);
        }
        await _store.write(StoredSession.managed(clean));
        if ((await _store.read())?.record != clean) {
          throw const SessionFailure(SessionFailureKind.storage);
        }
      });
    } catch (_) {
      if (_currentIntent(intent) &&
          isCurrent(lease.generation) &&
          _record?.marker == lease.marker) {
        _setGate(ReconciliationGate.storageBlocked);
      }
      rethrow;
    }
    if (!_currentIntent(intent) ||
        !isCurrent(lease.generation) ||
        _record?.marker != lease.marker) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    _record = clean;
    _setGate(ReconciliationGate.clean);
  }

  @override
  Future<ReconciliationGate> refreshReconciliation(int generation) async {
    final current = _record;
    if (!isCurrent(generation) || current == null) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    final intent = _revision;
    final stored = await _serialized(_store.read);
    if (!_currentIntent(intent) ||
        !isCurrent(generation) ||
        _record != current) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    final refreshed = stored?.record;
    if (refreshed == null ||
        refreshed.sessionId != current.sessionId ||
        refreshed.token != current.token) {
      _setGate(ReconciliationGate.storageBlocked);
      throw const SessionFailure(SessionFailureKind.storage);
    }
    _record = refreshed;
    _setGate(_gate(refreshed.marker));
    return _state.reconciliation;
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _token = null;
    _record = null;
    _changes.close();
  }
}
