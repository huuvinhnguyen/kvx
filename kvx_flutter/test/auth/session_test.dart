import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/domain/auth/session.dart';
import 'package:kvx_flutter/application/auth/session_coordinator.dart';
import 'package:kvx_flutter/data/auth/authenticated_transport.dart';
import 'package:kvx_flutter/data/auth/password_authenticator.dart';
import 'package:kvx_flutter/data/auth/secure_session_store.dart';

class MemoryStore implements SessionStore {
  StoredSession? value;
  int reads = 0, deletes = 0;
  final writes = <StoredSession>[];
  bool failRead = false, failWrite = false, failDelete = false;
  Completer<void>? readGate, writeGate;
  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();
  MemoryStore([this.value]);
  @override
  Future<StoredSession?> read() async {
    reads++;
    final captured = value;
    if (!readStarted.isCompleted) readStarted.complete();
    await readGate?.future;
    if (failRead) throw StateError('read failed');
    return captured;
  }

  @override
  Future<void> write(StoredSession value) async {
    writes.add(value);
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    if (failWrite) throw StateError('write failed');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (failDelete) throw StateError('delete failed');
    value = null;
  }
}

class FakeLogin implements PasswordAuthenticator {
  int calls = 0;
  String token = 'session-B';
  bool fails = false;
  Completer<String>? gate;
  final started = Completer<void>();
  @override
  Future<String> login(String username, String password) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (fails) throw StateError('credentials rejected');
    return gate == null ? token : await gate!.future;
  }
}

Matcher failure(SessionFailureKind kind) =>
    isA<SessionFailure>().having((e) => e.kind, 'kind', kind);
SessionCoordinator coordinator(MemoryStore store, [FakeLogin? login]) =>
    SessionCoordinator(store: store, authentication: login ?? FakeLogin());

class ConstructionRace implements SessionAccess {
  bool dispatched = false;
  @override
  SessionSnapshot snapshot({int? expectedGeneration}) =>
      const SessionSnapshot('old-session', 1);
  @override
  bool isCurrent(int generation) => false;
  @override
  Future<T> dispatch<T>(int generation, Future<T> Function() start) {
    throw const SessionFailure(SessionFailureKind.stale);
  }

  @override
  Future<bool> unauthorized(int generation) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('session lifecycle', () {
    test(
      'opaque active token restores once locally without authentication',
      () async {
        final store = MemoryStore(const StoredSession.active('opaque'));
        final login = FakeLogin();
        final session = coordinator(store, login);
        await session.restore();
        await session.restore();
        expect(session.state.phase, SessionPhase.authenticated);
        expect(session.snapshot().token, 'opaque');
        expect(store.reads, 1);
        expect(login.calls, 0);
        session.dispose();
      },
    );
    test('absent and signedOut storage never starts login', () async {
      for (final stored in [null, const StoredSession.signedOut()]) {
        final login = FakeLogin();
        final session = coordinator(MemoryStore(stored), login);
        await session.restore();
        expect(session.state.phase, SessionPhase.signedOut);
        expect(login.calls, 0);
        session.dispose();
      }
    });
    test('storage read failure remains retryable', () async {
      final store = MemoryStore(const StoredSession.active('opaque'))
        ..failRead = true;
      final session = coordinator(store);
      await session.restore();
      expect(session.state.phase, SessionPhase.restoring);
      expect(session.state.message, isNotNull);
      store.failRead = false;
      await session.restore();
      expect(session.state.phase, SessionPhase.authenticated);
      session.dispose();
    });
    test('login waits for durable persistence before publication', () async {
      final store = MemoryStore()..writeGate = Completer<void>();
      final session = coordinator(store);
      await session.restore();
      final pending = session.login('fixture', 'fixture');
      await store.writeStarted.future;
      expect(session.state.phase, SessionPhase.authenticating);
      store.writeGate!.complete();
      await pending;
      expect(session.snapshot().token, 'session-B');
      expect(store.value!.token, 'session-B');
      session.dispose();
    });
    test('rejected, whitespace and failed persistence never install', () async {
      for (final kind in ['rejected', 'invalid', 'storage']) {
        final store = MemoryStore()..failWrite = kind == 'storage';
        final login = FakeLogin()
          ..fails = kind == 'rejected'
          ..token = kind == 'invalid' ? ' \n' : 'session-B';
        final session = coordinator(store, login);
        await session.restore();
        await expectLater(
          session.login('fixture', 'fixture'),
          throwsA(isA<SessionFailure>()),
        );
        expect(session.state.phase, SessionPhase.signedOut);
        expect(
          () => session.snapshot(),
          throwsA(failure(SessionFailureKind.signedOut)),
        );
        session.dispose();
      }
    });
    test('concurrent 401 causes one invalidation and one clear', () async {
      final store = MemoryStore(const StoredSession.active('A'));
      final session = coordinator(store);
      await session.restore();
      final generation = session.snapshot().generation;
      final accepted = await Future.wait([
        session.unauthorized(generation),
        session.unauthorized(generation),
      ]);
      expect(accepted.where((v) => v), hasLength(1));
      expect(store.writes, hasLength(1));
      expect(session.state.reason, SignOutReason.expired);
      session.dispose();
    });
    test('logout persists signedOut even if delete is unavailable', () async {
      final store = MemoryStore(const StoredSession.active('A'))
        ..failDelete = true;
      final session = coordinator(store);
      await session.restore();
      expect(await session.logout(), isTrue);
      final restarted = coordinator(store);
      await restarted.restore();
      expect(restarted.state.phase, SessionPhase.signedOut);
      session.dispose();
      restarted.dispose();
    });
    test('failed signedOut write falls back to successful deletion', () async {
      final store = MemoryStore(const StoredSession.active('A'))
        ..failWrite = true;
      final session = coordinator(store);
      await session.restore();
      expect(await session.logout(), isTrue);
      expect(store.deletes, 1);
      expect(store.value, isNull);
      session.dispose();
    });
    test(
      'total clearing failure blocks runtime and switch; restart can restore surviving token',
      () async {
        final store = MemoryStore(const StoredSession.active('A'))
          ..failWrite = true
          ..failDelete = true;
        final login = FakeLogin();
        final session = coordinator(store, login);
        await session.restore();
        expect(await session.logout(), isFalse);
        expect(session.state.message, isNotNull);
        expect(
          () => session.snapshot(),
          throwsA(failure(SessionFailureKind.signedOut)),
        );
        await expectLater(
          session.switchAccount('fixture', 'fixture'),
          throwsA(failure(SessionFailureKind.storage)),
        );
        expect(login.calls, 0);
        final restarted = coordinator(store);
        await restarted.restore();
        expect(restarted.snapshot().token, 'A');
        session.dispose();
        restarted.dispose();
      },
    );
    test('logout fences late login before it can write', () async {
      final store = MemoryStore();
      final login = FakeLogin()..gate = Completer<String>();
      final session = coordinator(store, login);
      await session.restore();
      final pending = session.login('fixture', 'fixture');
      final assertion = expectLater(
        pending,
        throwsA(failure(SessionFailureKind.stale)),
      );
      await login.started.future;
      expect(await session.logout(), isTrue);
      login.gate!.complete('B');
      await assertion;
      expect(store.writes.map((s) => s.token), [null]);
      session.dispose();
    });
    test(
      'logout serializes behind pending write and rejects login while clearing',
      () async {
        final store = MemoryStore()..writeGate = Completer<void>();
        final login = FakeLogin();
        final session = coordinator(store, login);
        await session.restore();
        final pending = session.login('fixture', 'fixture');
        final assertion = expectLater(
          pending,
          throwsA(failure(SessionFailureKind.stale)),
        );
        await store.writeStarted.future;
        final logout = session.logout();
        expect(session.state.clearing, isTrue);
        await expectLater(
          session.login('fixture', 'fixture'),
          throwsA(failure(SessionFailureKind.signedOut)),
        );
        store.writeGate!.complete();
        await assertion;
        expect(await logout, isTrue);
        expect(store.value!.token, isNull);
        session.dispose();
      },
    );
    test('logout fences pending restoration', () async {
      final store = MemoryStore(const StoredSession.active('A'))
        ..readGate = Completer<void>();
      final session = coordinator(store);
      final restore = session.restore();
      await store.readStarted.future;
      final logout = session.logout();
      store.readGate!.complete();
      await restore;
      expect(await logout, isTrue);
      expect(session.state.phase, SessionPhase.signedOut);
      session.dispose();
    });
    test(
      'same token switch still creates new generation; stale 401 cannot terminate it',
      () async {
        final login = FakeLogin()..token = 'same';
        final session = coordinator(
          MemoryStore(const StoredSession.active('same')),
          login,
        );
        await session.restore();
        final old = session.snapshot();
        await session.switchAccount('fixture', 'fixture');
        expect(session.snapshot().generation, isNot(old.generation));
        expect(await session.unauthorized(old.generation), isFalse);
        expect(session.state.phase, SessionPhase.authenticated);
        session.dispose();
      },
    );
    test('failed switch login leaves A ended', () async {
      final session = coordinator(
        MemoryStore(const StoredSession.active('A')),
        FakeLogin()..fails = true,
      );
      await session.restore();
      await expectLater(
        session.switchAccount('fixture', 'fixture'),
        throwsA(isA<SessionFailure>()),
      );
      expect(session.state.phase, SessionPhase.signedOut);
      session.dispose();
    });
  });
  group('authenticated transport', () {
    test(
      'offline restore, retries, 503, 401 and logout never initiate login',
      () async {
        final login = FakeLogin();
        final session = coordinator(
          MemoryStore(const StoredSession.active('A')),
          login,
        );
        await session.restore();
        final paths = <String>[];
        final client = MockClient((r) async {
          paths.add(r.url.path);
          expect(r.headers['Authorization'], 'Bearer A');
          if (r.url.path == '/offline') throw http.ClientException('offline');
          return http.Response('', int.parse(r.url.path.substring(1)));
        });
        final transport = AuthenticatedTransport(
          authority: session,
          generation: session.state.generation,
          client: client,
        );
        for (var i = 0; i < 2; i++) {
          await expectLater(
            transport.send('GET', Uri.parse('https://test/offline')),
            throwsA(isA<http.ClientException>()),
          );
        }
        expect(session.state.phase, SessionPhase.authenticated);
        expect(
          (await transport.send(
            'GET',
            Uri.parse('https://test/503'),
          )).statusCode,
          503,
        );
        expect(session.state.phase, SessionPhase.authenticated);
        await transport.send('POST', Uri.parse('https://test/401'));
        expect(session.state.reason, SignOutReason.expired);
        await expectLater(
          transport.send('GET', Uri.parse('https://test/200')),
          throwsA(isA<SessionFailure>()),
        );
        await session.logout();
        expect(login.calls, 0);
        expect(paths, ['/offline', '/offline', '/503', '/401']);
        session.dispose();
        client.close();
      },
    );
    for (final status in [200, 401]) {
      test('late A $status is discarded after B login', () async {
        final session = coordinator(
          MemoryStore(const StoredSession.active('A')),
        );
        await session.restore();
        final response = Completer<http.Response>(),
            started = Completer<void>();
        final client = MockClient((r) {
          expect(r.headers['Authorization'], 'Bearer A');
          started.complete();
          return response.future;
        });
        final transport = AuthenticatedTransport(
          authority: session,
          generation: session.state.generation,
          client: client,
        );
        final pending = transport.send('GET', Uri.parse('https://test/device'));
        final assertion = expectLater(
          pending,
          throwsA(failure(SessionFailureKind.stale)),
        );
        await started.future;
        await session.switchAccount('fixture', 'fixture');
        response.complete(http.Response('old account', status));
        await assertion;
        expect(session.snapshot().token, 'session-B');
        await expectLater(
          transport.send('GET', Uri.parse('https://test/device')),
          throwsA(failure(SessionFailureKind.stale)),
        );
        session.dispose();
        client.close();
      });
    }
    test(
      'generation change during request construction prevents dispatch',
      () async {
        var calls = 0;
        final client = MockClient((r) async {
          calls++;
          return http.Response('', 200);
        });
        final transport = AuthenticatedTransport(
          authority: ConstructionRace(),
          generation: 1,
          client: client,
        );
        await expectLater(
          transport.send('POST', Uri.parse('https://test/mutation')),
          throwsA(failure(SessionFailureKind.stale)),
        );
        expect(calls, 0);
        client.close();
      },
    );
  });
  group('password contract', () {
    test('POST preserves payload and returns opaque token', () async {
      final client = MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/login');
        expect(r.headers.containsKey('Authorization'), isFalse);
        expect(jsonDecode(r.body), {
          'username': 'fixture',
          'password': 'fixture',
        });
        return http.Response('{"token":"opaque"}', 200);
      });
      expect(
        await BinblogPasswordAuthenticator(client).login('fixture', 'fixture'),
        'opaque',
      );
      client.close();
    });
    test('rejects invalid token responses and backend failure', () async {
      for (final body in [
        '{}',
        '{"token":null}',
        '{"token":1}',
        '{"token":""}',
        '{"token":"   "}',
      ]) {
        final client = MockClient((r) async => http.Response(body, 200));
        await expectLater(
          BinblogPasswordAuthenticator(client).login('fixture', 'fixture'),
          throwsA(failure(SessionFailureKind.invalidToken)),
        );
        client.close();
      }
      final client = MockClient((r) async => http.Response('{}', 401));
      await expectLater(
        BinblogPasswordAuthenticator(client).login('fixture', 'fixture'),
        throwsA(failure(SessionFailureKind.login)),
      );
      client.close();
    });
  });
  group('secure adapter plugin mock', () {
    const key = 'binblog.khuonvien.vn.session.v1';
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    test(
      'round trips active and token-free signedOut, then deletion',
      () async {
        const store = SecureSessionStore();
        expect(await store.read(), isNull);
        await store.write(const StoredSession.active('opaque'));
        expect((await store.read())!.token, 'opaque');
        await store.write(const StoredSession.signedOut());
        expect((await store.read())!.token, isNull);
        final raw = await const FlutterSecureStorage().read(key: key);
        expect(jsonDecode(raw!), isNot(contains('token')));
        await store.delete();
        expect(await store.read(), isNull);
      },
    );
    test(
      'corrupt, unknown version, blank and signedOut-with-token records fail closed',
      () async {
        for (final raw in [
          'bad-json',
          '{"version":2,"state":"active","token":"A"}',
          '{"version":1,"state":"active","token":" "}',
          '{"version":1,"state":"signedOut","token":"A"}',
        ]) {
          FlutterSecureStorage.setMockInitialValues({key: raw});
          await expectLater(
            const SecureSessionStore().read(),
            throwsA(anything),
          );
        }
      },
    );
  });
}
