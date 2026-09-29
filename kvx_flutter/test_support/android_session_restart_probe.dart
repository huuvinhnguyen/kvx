// Test-only Android entrypoint. Never use this target for a production build.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kvx_flutter/application/auth/session_coordinator.dart';
import 'package:kvx_flutter/data/auth/secure_session_store.dart';
import 'package:kvx_flutter/domain/auth/session.dart';

const _syntheticA = 'kvx-restart-test-session-A';
const _syntheticB = 'kvx-restart-test-session-B';
const _commandPath =
    '/data/user/0/com.kvx.kvx_flutter/files/auth-restart-probe-command';

class _SyntheticAuthenticator implements PasswordAuthenticator {
  @override
  Future<String> login(String username, String password) async =>
      switch (username) {
        'A' => _syntheticA,
        'B' => _syntheticB,
        _ => throw StateError('Unknown synthetic account'),
      };
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _requireSyntheticOrSignedOut(SessionCoordinator coordinator) {
  if (coordinator.state.phase == SessionPhase.signedOut &&
      coordinator.state.message == null) {
    return;
  }
  if (coordinator.state.phase == SessionPhase.authenticated) {
    final token = coordinator.snapshot().token;
    if (token == _syntheticA || token == _syntheticB) return;
  }
  // Preserve any existing real/unreadable session on a reused emulator.
  throw StateError(
    'Probe refuses to replace an existing or unreadable session',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Text('Auth restart probe'))));
  String action = 'unread';
  final coordinator = SessionCoordinator(
    store: const SecureSessionStore(),
    authentication: _SyntheticAuthenticator(),
  );
  try {
    action = (await File(_commandPath).readAsString()).trim();
    await coordinator.restore();
    switch (action) {
      case 'login-a':
        _requireSyntheticOrSignedOut(coordinator);
        _expect(await coordinator.logout(), 'Initial clearing failed');
        await coordinator.login('A', 'synthetic-only');
        _expect(
          coordinator.state.phase == SessionPhase.authenticated,
          'Login was not authenticated after acknowledgement',
        );
      case 'restore-a':
        _expect(
          coordinator.snapshot().token == _syntheticA,
          'Fresh process did not restore A',
        );
      case 'logout':
        _expect(
          coordinator.snapshot().token == _syntheticA,
          'Logout did not start from A',
        );
        _expect(await coordinator.logout(), 'Durable logout failed');
      case 'restore-signed-out':
        _expect(
          coordinator.state.phase == SessionPhase.signedOut &&
              coordinator.state.message == null,
          'Fresh process did not restore signed out',
        );
      case 'restore-error':
        _expect(
          coordinator.state.phase == SessionPhase.restoring &&
              coordinator.state.message != null,
          'Corrupt storage was classified as absent or authenticated',
        );
      case 'switch-b':
        _expect(
          coordinator.snapshot().token == _syntheticA,
          'Switch did not start from A',
        );
        await coordinator.switchAccount('B', 'synthetic-only');
        _expect(
          coordinator.state.phase == SessionPhase.authenticated,
          'Switch was not authenticated after acknowledgement',
        );
      case 'restore-b':
        _expect(
          coordinator.snapshot().token == _syntheticB,
          'Fresh process did not restore B',
        );
      case 'cleanup':
        _expect(await coordinator.logout(), 'Cleanup clearing failed');
      default:
        throw StateError('Unknown probe action');
    }
    // The mutation cases do not read storage back, sleep, or wait for lifecycle
    // shutdown. This marker immediately follows the coordinator/adapter await.
    print('KVX_AUTH_RESTART_PROBE PASS action=$action pid=$pid');
  } catch (error) {
    // Do not log storage contents, candidates, exception messages or secrets.
    print(
      'KVX_AUTH_RESTART_PROBE FAIL action=$action pid=$pid '
      'error=${error.runtimeType}',
    );
  } finally {
    coordinator.dispose();
  }
}
