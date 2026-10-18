import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:kvx_flutter/application/auth/account_authentication_controller.dart';
import 'package:kvx_flutter/application/auth/session_coordinator.dart';
import 'package:kvx_flutter/data/auth/auth_management_client.dart';
import 'package:kvx_flutter/domain/auth/account_authentication.dart';
import 'package:kvx_flutter/domain/auth/session.dart';
import 'package:kvx_flutter/presentation/screens/account_methods_screen.dart';

class TestAuthority implements SessionAccess, ReconciliationAccess {
  bool current = true;
  int expired = 0;
  final _recordId = '11111111-1111-4111-8111-111111111111';
  ReconciliationMarker? _marker;
  @override
  SessionSnapshot snapshot({int? expectedGeneration}) {
    if (!current || expectedGeneration != 7) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return const SessionSnapshot('dummy-binblog-session', 7);
  }

  @override
  bool isCurrent(int generation) => current && generation == 7;
  @override
  Future<T> dispatch<T>(int generation, Future<T> Function() start) {
    if (!isCurrent(generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return start();
  }

  @override
  Future<bool> unauthorized(int generation) async {
    if (!isCurrent(generation)) return false;
    expired++;
    current = false;
    return true;
  }

  @override
  ReconciliationGate reconciliationGate(int generation) {
    if (!isCurrent(generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return switch (_marker?.operation) {
      null => ReconciliationGate.clean,
      ReconciliationOperation.unlinkGoogle => ReconciliationGate.pendingUnlink,
      ReconciliationOperation.rotateRecoveryCodes =>
        ReconciliationGate.pendingRotation,
    };
  }

  @override
  Future<ReconciliationGate> refreshReconciliation(int generation) async =>
      reconciliationGate(generation);

  @override
  Future<MutationLease> prepareMutation(
    ReconciliationOperation operation,
    int generation,
  ) async {
    if (!isCurrent(generation) || _marker != null) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    final marker = ReconciliationMarker(operation);
    _marker = marker;
    return MutationLease(generation, _recordId, marker);
  }

  @override
  MutationLease? pendingMutation(int generation) {
    if (!isCurrent(generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    final marker = _marker;
    return marker == null ? null : MutationLease(generation, _recordId, marker);
  }

  @override
  Future<void> clearMutation(
    MutationLease lease,
    MarkerResolution resolution,
  ) async {
    if (!isCurrent(lease.generation) ||
        lease.sessionId != _recordId ||
        _marker != lease.marker) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    _marker = null;
  }

  @override
  Future<T> dispatchPrepared<T>(
    MutationLease lease,
    Future<T> Function() start,
  ) {
    if (!isCurrent(lease.generation) ||
        lease.sessionId != _recordId ||
        _marker != lease.marker) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return start();
  }
}

class MarkerStoreFixture implements SessionStore {
  StoredSession? value;
  int writes = 0;
  bool failMarkedWrite = false;
  bool failMarkerClear = false;
  MarkerStoreFixture(this.value);
  @override
  Future<StoredSession?> read() async => value;
  @override
  Future<void> write(StoredSession next) async {
    writes++;
    if (failMarkedWrite && next.record?.marker != null) {
      throw StateError('local marker write fault');
    }
    if (failMarkerClear && next.record?.marker == null) {
      throw StateError('local marker clear fault');
    }
    value = next;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class MarkerLoginFixture implements PasswordAuthenticator {
  @override
  Future<String> login(String username, String password) async => 'dummy-jwt';
}

http.Response jsonResponse(int status, Object json) => http.Response(
  jsonEncode(json),
  status,
  headers: {'content-type': 'application/json'},
);

class FakeRepository implements AccountAuthRepository {
  AuthenticationMethods value = const AuthenticationMethods(true, [
    ProviderMethod('google', true, true),
  ], false);
  Completer<AuthenticationMethods>? pendingMethods;
  Completer<ReauthenticationGrant>? pendingReauth;
  Completer<void>? beforeMutationDispatch;
  Completer<void>? pendingMutation;
  AccountAuthFailure? mutationFailure;
  int reauthCalls = 0;
  int rotateCalls = 0;
  int unlinkCalls = 0;
  int cancelCalls = 0;
  int methodsCalls = 0;
  bool failReconcile = false;
  @override
  Future<AuthenticationMethods> methods() async {
    methodsCalls++;
    if (pendingMethods != null) return pendingMethods!.future;
    if (failReconcile) {
      throw const AccountAuthFailure(AccountAuthFailureKind.network);
    }
    return value;
  }

  @override
  Future<ReauthenticationGrant> reauthenticate(
    String password,
    ReauthenticationPurpose purpose,
  ) async {
    reauthCalls++;
    if (pendingReauth != null) return pendingReauth!.future;
    return ReauthenticationGrant(
      'dummy-grant',
      DateTime.now().add(const Duration(minutes: 4)),
      purpose,
    );
  }

  @override
  Future<List<String>> rotateCodes(
    ReauthenticationGrant grant, {
    required MutationLease lease,
    required bool Function() beginDispatch,
  }) async {
    if (beforeMutationDispatch != null) await beforeMutationDispatch!.future;
    if (!beginDispatch()) {
      throw const AccountAuthFailure(AccountAuthFailureKind.cancelled);
    }
    rotateCalls++;
    if (pendingMutation != null) await pendingMutation!.future;
    if (mutationFailure != null) throw mutationFailure!;
    return List.generate(10, (i) => 'dummy-code-$i');
  }

  @override
  Future<void> unlinkGoogle(
    ReauthenticationGrant grant, {
    required MutationLease lease,
    required bool Function() beginDispatch,
  }) async {
    if (beforeMutationDispatch != null) await beforeMutationDispatch!.future;
    if (!beginDispatch()) {
      throw const AccountAuthFailure(AccountAuthFailureKind.cancelled);
    }
    unlinkCalls++;
    if (pendingMutation != null) await pendingMutation!.future;
    if (mutationFailure != null) throw mutationFailure!;
    value = const AuthenticationMethods(true, [], false);
  }

  @override
  void cancel() {
    cancelCalls++;
  }
}

class StreamingClient extends http.BaseClient {
  final List<List<int>> chunks;
  final Map<String, String> headers;
  StreamingClient(this.chunks, this.headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.fromIterable(chunks),
        200,
        headers: headers,
      );
}

class LoopbackRewriteClient extends http.BaseClient {
  final IOClient inner;
  final Uri loopback;
  LoopbackRewriteClient(this.inner, this.loopback);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final rewritten =
        http.AbortableRequest(
            request.method,
            loopback.resolve(request.url.path),
            abortTrigger: request is http.AbortableRequest
                ? request.abortTrigger
                : null,
          )
          ..headers.addAll(request.headers)
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection;
    if (request is http.Request) rewritten.bodyBytes = request.bodyBytes;
    return inner.send(rewritten);
  }

  @override
  void close() => inner.close();
}

void main() {
  testWidgets('restored rotation warning is visible before methods returns', (
    tester,
  ) async {
    final authority = TestAuthority();
    authority._marker = ReconciliationMarker(
      ReconciliationOperation.rotateRecoveryCodes,
    );
    final pending = Completer<http.Response>();
    final client = MockClient((request) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountMethodsScreen(
          authority: authority,
          generation: 7,
          client: client,
          continuity: AccountMethodsContinuity(
            7,
            gate: ReconciliationGate.pendingRotation,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Mã trước đó có thể đã bị hủy'), findsOneWidget);
    expect(find.textContaining('Không thể thay đổi tài khoản'), findsOneWidget);
    expect(find.text('Tôi hiểu, cho phép tạo bộ mã khác'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    pending.complete(
      jsonResponse(503, {'status': 'error', 'code': 'server_error'}),
    );
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('Google-only methods screen has no password-backed actions', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => jsonResponse(200, {
        'status': 'success',
        'password': {'usable': false},
        'providers': [
          {'provider': 'google', 'usable': true, 'can_unlink': false},
        ],
        'recovery': {'codes_enrolled': false},
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountMethodsScreen(
          authority: TestAuthority(),
          generation: 7,
          client: client,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Gỡ Google'), findsNothing);
    expect(find.text('Tạo mã khôi phục'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });

  testWidgets('mixed password account exposes only scoped actions', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': [
          {'provider': 'google', 'usable': true, 'can_unlink': true},
        ],
        'recovery': {'codes_enrolled': true},
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountMethodsScreen(
          authority: TestAuthority(),
          generation: 7,
          client: client,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Xoay mã khôi phục'), findsOneWidget);
    expect(find.text('Gỡ Google'), findsOneWidget);
    expect(find.text('Liên kết Google'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });

  testWidgets('inactive lifecycle clears an open password prompt', (
    tester,
  ) async {
    var mutations = 0;
    var reads = 0;
    final authority = TestAuthority();
    final client = MockClient((request) async {
      if (request.method != 'GET') mutations++;
      if (request.method == 'GET') reads++;
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': false},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountMethodsScreen(
            authority: authority,
            generation: 7,
            client: client,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(input.text, isNotEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(input.text, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpAndSettle();
      expect(() => input.addListener(() {}), throwsFlutterError);
      expect(find.byType(AccountMethodsScreen), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Phương thức đăng nhập'), findsOneWidget);
      expect(mutations, 0);
      expect(reads, 1);
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(mutations, 0);
      expect(authority.current, isTrue);
      expect(authority.expired, 0);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  testWidgets('background removes only the owned password dialog route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var mutations = 0;
    final authority = TestAuthority();
    final client = MockClient((request) async {
      if (request.method != 'GET') mutations++;
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': false},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: AccountMethodsScreen(
            authority: authority,
            generation: 7,
            client: client,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(find.byType(AlertDialog), findsOneWidget);
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other route')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Other route'), findsOneWidget);
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(find.byType(TextField, skipOffstage: false), findsNothing);
      await tester.pumpAndSettle();
      expect(() => input.addListener(() {}), throwsFlutterError);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Other route'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Other route'), findsOneWidget);
      expect(mutations, 0);
      expect(authority.current, isTrue);
    } finally {
      if (tester.binding.lifecycleState == AppLifecycleState.paused) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      if (tester.binding.lifecycleState == AppLifecycleState.inactive) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  testWidgets(
    'cancelling a password dialog never dispatches reauthentication',
    (tester) async {
      var mutations = 0;
      final client = MockClient((request) async {
        if (request.method != 'GET') mutations++;
        return jsonResponse(200, {
          'status': 'success',
          'password': {'usable': true},
          'providers': <Object>[],
          'recovery': {'codes_enrolled': false},
        });
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: AccountMethodsScreen(
              authority: TestAuthority(),
              generation: 7,
              client: client,
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tạo mã khôi phục'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'dummy-password');
        final input = tester
            .widget<TextField>(find.byType(TextField))
            .controller!;
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(() => input.addListener(() {}), throwsFlutterError);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Phương thức đăng nhập'), findsOneWidget);
        expect(mutations, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        client.close();
      }
    },
  );

  testWidgets('removing account screen releases its owned dialog and input', (
    tester,
  ) async {
    final visible = ValueNotifier<bool>(true);
    final authority = TestAuthority();
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET') writes++;
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': false},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, child) => show
                ? AccountMethodsScreen(
                    authority: authority,
                    generation: 7,
                    client: client,
                  )
                : const Scaffold(body: Text('Replacement root')),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Replacement root'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(input.text, isEmpty);
      expect(() => input.addListener(() {}), throwsFlutterError);
      expect(writes, 0);
      visible.value = true;
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(authority.current, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      visible.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  testWidgets('force-disposing Navigator completes dialog input cleanup', (
    tester,
  ) async {
    final authority = TestAuthority();
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET') writes++;
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': false},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountMethodsScreen(
            authority: authority,
            generation: 7,
            client: client,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      authority.current = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(input.text, isEmpty);
      expect(() => input.addListener(() {}), throwsFlutterError);
      expect(find.byType(AlertDialog), findsNothing);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  testWidgets('inactive dialog cleanup survives immediate root teardown', (
    tester,
  ) async {
    final authority = TestAuthority();
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET') writes++;
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': false},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountMethodsScreen(
            authority: authority,
            generation: 7,
            client: client,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(input.text, isEmpty);
      expect(() => input.addListener(() {}), throwsFlutterError);
      expect(find.byType(AlertDialog), findsNothing);
      expect(writes, 0);
      expect(authority.current, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  testWidgets('teardown removes owned dialog beneath another route only', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final visible = ValueNotifier<bool>(true);
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET') writes++;
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': false},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, child) => show
                ? AccountMethodsScreen(
                    authority: TestAuthority(),
                    generation: 7,
                    client: client,
                  )
                : const Scaffold(body: Text('Replacement root')),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other route')),
        ),
      );
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Other route'), findsOneWidget);
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(input.text, isEmpty);
      expect(() => input.addListener(() {}), throwsFlutterError);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    } finally {
      visible.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  testWidgets('inactive lifecycle removes displayed codes from widget tree', (
    tester,
  ) async {
    var rotations = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/reauthentications') {
        return jsonResponse(200, {
          'status': 'success',
          'reauthentication_token': 'dummy-grant',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      }
      if (request.url.path == '/api/auth/recovery_codes') {
        rotations++;
        return jsonResponse(200, {
          'status': 'success',
          'code': 'recovery_codes_rotated',
          'codes': List.generate(10, (i) => 'dummy-code-$i'),
        });
      }
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': <Object>[],
        'recovery': {'codes_enrolled': rotations > 0},
      });
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountMethodsScreen(
            authority: TestAuthority(),
            generation: 7,
            client: client,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã khôi phục'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dummy-password');
      await tester.tap(find.text('Xác minh và tiếp tục'));
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.text('dummy-code-0').evaluate().isNotEmpty) break;
      }
      expect(rotations, 1);
      expect(find.text('dummy-code-0'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('dummy-code-0'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('dummy-code-0'), findsNothing);
      expect(rotations, 1);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  });

  test('methods projection uses fixed endpoint and Binblog session', () async {
    final authority = TestAuthority();
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://khuonvien.vn/api/auth/methods');
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer dummy-binblog-session');
      return jsonResponse(200, {
        'status': 'success',
        'password': {'usable': true},
        'providers': [
          {'provider': 'google', 'usable': true, 'can_unlink': true},
        ],
        'recovery': {'codes_enrolled': false},
      });
    });
    final result = await AuthManagementClient(
      authority: authority,
      generation: 7,
      client: client,
    ).methods();
    expect(result.canUnlinkGoogle, isTrue);
    expect(result.codesEnrolled, isFalse);
    client.close();
  });

  test('only parsed authentication_required expires current session', () async {
    for (final code in [
      'authentication_required',
      'invalid_provider_credential',
      'other',
    ]) {
      final authority = TestAuthority();
      final client = MockClient(
        (_) async => jsonResponse(401, {'status': 'error', 'code': code}),
      );
      final operation = AuthManagementClient(
        authority: authority,
        generation: 7,
        client: client,
      ).methods();
      await expectLater(operation, throwsA(isA<AccountAuthFailure>()));
      expect(authority.expired, code == 'authentication_required' ? 1 : 0);
      client.close();
    }
  });

  test('malformed 401 and malformed methods do not expire session', () async {
    final authority = TestAuthority();
    final malformed401 = MockClient(
      (_) async => jsonResponse(401, {'status': 'error', 'code': 4}),
    );
    await expectLater(
      AuthManagementClient(
        authority: authority,
        generation: 7,
        client: malformed401,
      ).methods(),
      throwsA(isA<AccountAuthFailure>()),
    );
    expect(authority.expired, 0);
    malformed401.close();
    final malformedMethods = MockClient(
      (_) async => jsonResponse(200, {
        'status': 'success',
        'password': {'usable': 'yes'},
        'providers': [],
        'recovery': {'codes_enrolled': false},
      }),
    );
    await expectLater(
      AuthManagementClient(
        authority: authority,
        generation: 7,
        client: malformedMethods,
      ).methods(),
      throwsA(isA<AccountAuthFailure>()),
    );
    expect(authority.expired, 0);
    malformedMethods.close();
  });

  test('stable mutation failures preserve session', () async {
    for (final fixture in [
      (
        403,
        'reauthentication_failed',
        AccountAuthFailureKind.reauthenticationFailed,
      ),
      (
        403,
        'reauthentication_required',
        AccountAuthFailureKind.reauthenticationRequired,
      ),
      (
        409,
        'last_authentication_method',
        AccountAuthFailureKind.lastAuthenticationMethod,
      ),
      (422, 'unsupported_provider', AccountAuthFailureKind.unsupportedProvider),
      (429, 'rate_limited', AccountAuthFailureKind.rateLimited),
      (500, 'internal_error', AccountAuthFailureKind.serverFailure),
    ]) {
      final authority = TestAuthority();
      final client = MockClient(
        (_) async =>
            jsonResponse(fixture.$1, {'status': 'error', 'code': fixture.$2}),
      );
      final repo = AuthManagementClient(
        authority: authority,
        generation: 7,
        client: client,
      );
      try {
        await repo.reauthenticate(
          'dummy-password',
          ReauthenticationPurpose.rotateRecoveryCodes,
        );
        fail('expected ${fixture.$2}');
      } on AccountAuthFailure catch (failure) {
        expect(failure.kind, fixture.$3);
      }
      expect(authority.expired, 0);
      client.close();
    }
  });

  test('cancelling an in-flight request discards its late response', () async {
    final authority = TestAuthority();
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    final repo = AuthManagementClient(
      authority: authority,
      generation: 7,
      client: client,
    );
    final operation = repo.methods();
    await Future<void>.delayed(Duration.zero);
    repo.cancel();
    response.complete(
      jsonResponse(401, {'status': 'error', 'code': 'authentication_required'}),
    );
    await expectLater(operation, throwsA(isA<AccountAuthFailure>()));
    expect(authority.expired, 0);
    client.close();
  });

  test(
    'streaming body limit accepts boundary and rejects overflow without trusting Content-Length',
    () async {
      const projection =
          '{"status":"success","password":{"usable":true},"providers":[],"recovery":{"codes_enrolled":false}}';
      final valid = utf8.encode(projection);
      final padding = List<int>.filled(16 * 1024 - valid.length, 0x20);
      final boundary = StreamingClient(
        [valid, padding],
        {'content-type': 'application/json', 'content-length': '1'},
      );
      final parsed = await AuthManagementClient(
        authority: TestAuthority(),
        generation: 7,
        client: boundary,
      ).methods();
      expect(parsed.passwordUsable, isTrue);
      final oversized = StreamingClient(
        [
          valid,
          padding,
          [0x20],
        ],
        {'content-type': 'application/json'},
      );
      await expectLater(
        AuthManagementClient(
          authority: TestAuthority(),
          generation: 7,
          client: oversized,
        ).methods(),
        throwsA(
          isA<AccountAuthFailure>().having(
            (e) => e.kind,
            'kind',
            AccountAuthFailureKind.malformedResponse,
          ),
        ),
      );
      boundary.close();
      oversized.close();
    },
  );

  test('actual IOClient does not follow auth-management redirect', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = Uri.parse('http://127.0.0.1:${server.port}');
    var first = 0;
    var target = 0;
    final subscription = server.listen((request) async {
      if (request.uri.path == '/api/auth/methods') {
        first++;
        request.response.statusCode = 302;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          origin.resolve('/target').toString(),
        );
        request.response.write('{"status":"error","code":"redirect"}');
      } else if (request.uri.path == '/target') {
        target++;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"status":"error","code":"target"}');
      }
      await request.response.close();
    });
    final previous = HttpOverrides.current;
    LoopbackRewriteClient? client;
    try {
      HttpOverrides.global = null;
      client = LoopbackRewriteClient(IOClient(HttpClient()), origin);
      final repository = AuthManagementClient(
        authority: TestAuthority(),
        generation: 7,
        client: client,
      );
      await expectLater(
        repository.methods().timeout(const Duration(seconds: 3)),
        throwsA(
          isA<AccountAuthFailure>().having(
            (e) => e.kind,
            'kind',
            AccountAuthFailureKind.unknown,
          ),
        ),
      );
      expect(first, 1);
      expect(target, 0);
      final control = http.Request(
        'GET',
        Uri.parse('https://khuonvien.vn/api/auth/methods'),
      )..followRedirects = true;
      final redirected = await client
          .send(control)
          .timeout(const Duration(seconds: 3));
      await redirected.stream.drain<void>().timeout(const Duration(seconds: 3));
      expect(first, 2);
      expect(target, 1);
    } finally {
      HttpOverrides.global = previous;
      client?.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('old generation 401 is discarded before expiry', () async {
    final authority = TestAuthority();
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    final operation = AuthManagementClient(
      authority: authority,
      generation: 7,
      client: client,
    ).methods();
    await Future<void>.delayed(Duration.zero);
    authority.current = false;
    response.complete(
      jsonResponse(401, {'status': 'error', 'code': 'authentication_required'}),
    );
    await expectLater(operation, throwsA(isA<AccountAuthFailure>()));
    expect(authority.expired, 0);
    client.close();
  });

  test('grant purpose and expiry are enforced before mutation', () async {
    final expired = ReauthenticationGrant(
      'dummy',
      DateTime.now().subtract(const Duration(seconds: 1)),
      ReauthenticationPurpose.rotateRecoveryCodes,
    );
    expect(
      expired.usableFor(
        ReauthenticationPurpose.rotateRecoveryCodes,
        DateTime.now(),
      ),
      isFalse,
    );
    final valid = ReauthenticationGrant(
      'dummy',
      DateTime.now().add(const Duration(minutes: 1)),
      ReauthenticationPurpose.unlinkIdentity,
    );
    expect(
      valid.usableFor(
        ReauthenticationPurpose.rotateRecoveryCodes,
        DateTime.now(),
      ),
      isFalse,
    );
    expect(
      valid.consumeFor(ReauthenticationPurpose.unlinkIdentity, DateTime.now()),
      'dummy',
    );
    expect(
      valid.consumeFor(ReauthenticationPurpose.unlinkIdentity, DateTime.now()),
      isNull,
    );
    final client = MockClient((_) async {
      fail('must not send');
    });
    final authority = TestAuthority();
    final lease = await authority.prepareMutation(
      ReconciliationOperation.rotateRecoveryCodes,
      7,
    );
    final repo = AuthManagementClient(
      authority: authority,
      generation: 7,
      client: client,
    );
    await expectLater(
      repo.rotateCodes(valid, lease: lease, beginDispatch: () => true),
      throwsA(isA<AccountAuthFailure>()),
    );
    await expectLater(
      repo.rotateCodes(expired, lease: lease, beginDispatch: () => true),
      throwsA(isA<AccountAuthFailure>()),
    );
    client.close();
  });

  test('Google only state has no password backed mutation actions', () async {
    final repo = FakeRepository()
      ..value = const AuthenticationMethods(false, [
        ProviderMethod('google', true, false),
      ], false);
    final model = AccountAuthenticationController(
      repository: repo,
      authority: TestAuthority(),
      generation: 7,
    );
    await model.refresh();
    expect(model.canRotate, isFalse);
    expect(model.canUnlink, isFalse);
    await model.rotate('dummy-password');
    expect(repo.reauthCalls, 0);
    model.dispose();
  });

  test(
    'rotation is single operation and codes clear on acknowledgement',
    () async {
      final repo = FakeRepository();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      final loading = model.refresh();
      expect(model.writeInFlight, isFalse);
      await loading;
      final first = model.rotate('dummy-password');
      expect(model.writeInFlight, isTrue);
      await model.rotate('dummy-password');
      await first;
      expect(model.writeInFlight, isFalse);
      expect(repo.reauthCalls, 1);
      expect(repo.rotateCalls, 1);
      expect(model.codes, hasLength(10));
      model.acknowledgeCodes();
      expect(model.codes, isEmpty);
      model.dispose();
    },
  );

  test(
    'uncertain rotation reconciles but requires explicit acknowledgement',
    () async {
      final repo = FakeRepository()
        ..mutationFailure = const AccountAuthFailure(
          AccountAuthFailureKind.network,
        );
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      await model.refresh();
      await model.rotate('dummy-password');
      expect(model.lostCodes, isTrue);
      expect(model.canRotate, isFalse);
      expect(model.codes, isEmpty);
      await model.acknowledgeLostCodes();
      expect(model.canRotate, isTrue);
      model.dispose();
    },
  );

  test('failed reconciliation blocks another write', () async {
    final repo = FakeRepository();
    final model = AccountAuthenticationController(
      repository: repo,
      authority: TestAuthority(),
      generation: 7,
    );
    await model.refresh();
    repo.failReconcile = true;
    await model.unlink('dummy-password');
    expect(model.writeBlocked, isTrue);
    expect(model.canUnlink, isFalse);
    expect(repo.unlinkCalls, 1);
    model.dispose();
  });

  test(
    'unlink success reconciles and uncertain unlink is never replayed',
    () async {
      final repo = FakeRepository();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      await model.refresh();
      await model.unlink('dummy-password');
      expect(repo.unlinkCalls, 1);
      expect(model.methods?.google, isNull);
      model.dispose();

      final uncertain = FakeRepository()
        ..mutationFailure = const AccountAuthFailure(
          AccountAuthFailureKind.network,
        );
      final second = AccountAuthenticationController(
        repository: uncertain,
        authority: TestAuthority(),
        generation: 7,
      );
      await second.refresh();
      await second.unlink('dummy-password');
      expect(uncertain.unlinkCalls, 1);
      expect(second.methods?.canUnlinkGoogle, isTrue);
      second.dispose();
    },
  );

  test(
    'logout and disposal discard late methods and clear transient codes',
    () async {
      final repo = FakeRepository();
      final authority = TestAuthority();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: authority,
        generation: 7,
      );
      await model.refresh();
      await model.rotate('dummy-password');
      expect(model.codes, isNotEmpty);
      model.dispose();
      expect(model.codes, isEmpty);
      expect(repo.cancelCalls, 1);
      final pending = Completer<AuthenticationMethods>();
      repo.pendingMethods = pending;
      final newer = AccountAuthenticationController(
        repository: repo,
        authority: authority,
        generation: 7,
      );
      final refresh = newer.refresh();
      authority.current = false;
      pending.complete(const AuthenticationMethods(true, [], false));
      await refresh;
      expect(newer.methods, isNull);
      newer.dispose();
    },
  );

  test(
    'password reauthentication sends exact contract and decodes grant',
    () async {
      final authority = TestAuthority();
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://khuonvien.vn/api/auth/reauthentications',
        );
        expect(request.method, 'POST');
        expect(
          request.headers['Authorization'],
          'Bearer dummy-binblog-session',
        );
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'purpose': 'rotate_recovery_codes',
          'method': 'password',
          'password': 'dummy-password',
        });
        return jsonResponse(200, {
          'status': 'success',
          'reauthentication_token': 'dummy-grant',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      });
      try {
        final grant =
            await AuthManagementClient(
              authority: authority,
              generation: 7,
              client: client,
            ).reauthenticate(
              'dummy-password',
              ReauthenticationPurpose.rotateRecoveryCodes,
            );
        expect(
          grant.usableFor(
            ReauthenticationPurpose.rotateRecoveryCodes,
            DateTime.now(),
          ),
          isTrue,
        );
        expect(
          grant.usableFor(
            ReauthenticationPurpose.unlinkIdentity,
            DateTime.now(),
          ),
          isFalse,
        );
      } finally {
        client.close();
      }
    },
  );

  test('rotation sends one grant and decodes one-time receipt', () async {
    final authority = TestAuthority();
    var sends = 0;
    final client = MockClient((request) async {
      sends++;
      expect(
        request.url.toString(),
        'https://khuonvien.vn/api/auth/recovery_codes',
      );
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer dummy-binblog-session');
      expect(jsonDecode(request.body), {
        'reauthentication_token': 'dummy-grant',
      });
      return jsonResponse(200, {
        'status': 'success',
        'code': 'recovery_codes_rotated',
        'codes': List.generate(10, (i) => 'dummy-code-$i'),
      });
    });
    try {
      final repo = AuthManagementClient(
        authority: authority,
        generation: 7,
        client: client,
      );
      final grant = ReauthenticationGrant(
        'dummy-grant',
        DateTime.now().add(const Duration(minutes: 4)),
        ReauthenticationPurpose.rotateRecoveryCodes,
      );
      final lease = await authority.prepareMutation(
        ReconciliationOperation.rotateRecoveryCodes,
        7,
      );
      expect(
        await repo.rotateCodes(grant, lease: lease, beginDispatch: () => true),
        hasLength(10),
      );
      await expectLater(
        repo.rotateCodes(grant, lease: lease, beginDispatch: () => true),
        throwsA(
          isA<AccountAuthFailure>().having(
            (e) => e.kind,
            'kind',
            AccountAuthFailureKind.reauthenticationRequired,
          ),
        ),
      );
      expect(sends, 1);
    } finally {
      client.close();
    }
  });

  test(
    'DELETE contract accepts unlinked/not_linked and classifies failures',
    () async {
      for (final code in ['unlinked', 'not_linked']) {
        final authority = TestAuthority();
        final lease = await authority.prepareMutation(
          ReconciliationOperation.unlinkGoogle,
          7,
        );
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://khuonvien.vn/api/auth/social_identities/google',
          );
          expect(request.method, 'DELETE');
          expect(
            request.headers['Authorization'],
            'Bearer dummy-binblog-session',
          );
          expect(jsonDecode(request.body), {
            'reauthentication_token': 'dummy-grant',
          });
          return jsonResponse(200, {'status': 'success', 'code': code});
        });
        try {
          await AuthManagementClient(
            authority: authority,
            generation: 7,
            client: client,
          ).unlinkGoogle(
            ReauthenticationGrant(
              'dummy-grant',
              DateTime.now().add(const Duration(minutes: 4)),
              ReauthenticationPurpose.unlinkIdentity,
            ),
            lease: lease,
            beginDispatch: () => true,
          );
          expect(authority.expired, 0);
        } finally {
          client.close();
        }
      }
      for (final fixture in [
        (
          409,
          'last_authentication_method',
          AccountAuthFailureKind.lastAuthenticationMethod,
          0,
        ),
        (
          401,
          'invalid_provider_credential',
          AccountAuthFailureKind.invalidProviderCredential,
          0,
        ),
        (
          401,
          'authentication_required',
          AccountAuthFailureKind.authenticationRequired,
          1,
        ),
      ]) {
        final authority = TestAuthority();
        final lease = await authority.prepareMutation(
          ReconciliationOperation.unlinkGoogle,
          7,
        );
        final client = MockClient((request) async {
          expect(request.url.path, '/api/auth/social_identities/google');
          expect(request.method, 'DELETE');
          return jsonResponse(fixture.$1, {
            'status': 'error',
            'code': fixture.$2,
          });
        });
        try {
          await expectLater(
            AuthManagementClient(
              authority: authority,
              generation: 7,
              client: client,
            ).unlinkGoogle(
              ReauthenticationGrant(
                'dummy-grant',
                DateTime.now().add(const Duration(minutes: 4)),
                ReauthenticationPurpose.unlinkIdentity,
              ),
              lease: lease,
              beginDispatch: () => true,
            ),
            throwsA(
              isA<AccountAuthFailure>().having(
                (e) => e.kind,
                'kind',
                fixture.$3,
              ),
            ),
          );
          expect(authority.expired, fixture.$4);
        } finally {
          client.close();
        }
      }
    },
  );

  test('not_linked receipt reconciles both authoritative outcomes', () async {
    for (final providerRemains in [false, true]) {
      final authority = TestAuthority();
      final continuity = AccountMethodsContinuity(7);
      var reads = 0;
      var deletes = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/methods') {
          reads++;
          if (providerRemains && reads == 4) {
            return jsonResponse(503, {
              'status': 'error',
              'code': 'server_error',
            });
          }
          if (providerRemains && reads == 5) {
            return jsonResponse(200, {
              'status': 'success',
              'password': {'usable': 'yes'},
              'providers': <Object>[],
              'recovery': {'codes_enrolled': false},
            });
          }
          return jsonResponse(200, {
            'status': 'success',
            'password': {'usable': true},
            'providers': reads == 1 || (providerRemains && reads < 6)
                ? [
                    {'provider': 'google', 'usable': true, 'can_unlink': true},
                  ]
                : <Object>[],
            'recovery': {'codes_enrolled': false},
          });
        }
        if (request.url.path == '/api/auth/reauthentications') {
          expect(jsonDecode(request.body)['purpose'], 'unlink_identity');
          return jsonResponse(200, {
            'status': 'success',
            'reauthentication_token': 'dummy-grant',
            'expires_at': '2099-01-01T00:00:00Z',
          });
        }
        expect(request.url.path, '/api/auth/social_identities/google');
        expect(request.method, 'DELETE');
        deletes++;
        return jsonResponse(200, {'status': 'success', 'code': 'not_linked'});
      });
      var model = AccountAuthenticationController(
        repository: AuthManagementClient(
          authority: authority,
          generation: 7,
          client: client,
        ),
        authority: authority,
        generation: 7,
        continuity: continuity,
      );
      try {
        await model.refresh();
        expect(model.canUnlink, isTrue);
        await model.unlink('dummy-password');
        expect(reads, 2);
        expect(deletes, 1);
        expect(model.methods?.google != null, providerRemains);
        expect(model.writeBlocked, providerRemains);
        expect(model.canUnlink, isFalse);
        if (providerRemains) {
          expect(model.message, isNot('Đã cập nhật phương thức đăng nhập.'));
          model.dispose();
          expect(model.codes, isEmpty);
          expect(continuity.writeBlocked, isTrue);
          model = AccountAuthenticationController(
            repository: AuthManagementClient(
              authority: authority,
              generation: 7,
              client: client,
            ),
            authority: authority,
            generation: 7,
            continuity: continuity,
          );
          expect(model.writeBlocked, isTrue);
          expect(model.canUnlink, isFalse);
          for (final expectedReads in [3, 4, 5]) {
            await model.refresh();
            expect(reads, expectedReads);
            expect(model.methods?.google, isNotNull);
            expect(model.writeBlocked, isTrue);
            expect(model.canUnlink, isFalse);
            expect(model.message, isNot('Đã cập nhật phương thức đăng nhập.'));
            expect(deletes, 1);
          }
          await model.refresh();
          expect(reads, 6);
          expect(model.methods?.google, isNull);
          expect(model.writeBlocked, isFalse);
          expect(model.canUnlink, isFalse);
          expect(deletes, 1);
        }
      } finally {
        model.dispose();
        continuity.invalidate();
        client.close();
      }
    }
  });

  test('failed marker write sends zero DELETE requests', () async {
    final store = MarkerStoreFixture(
      StoredSession.managed(ActiveSessionRecord('dummy-jwt')),
    )..failMarkedWrite = true;
    final session = SessionCoordinator(
      store: store,
      authentication: MarkerLoginFixture(),
    );
    await session.restore();
    final generation = session.snapshot().generation;
    var deletes = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return jsonResponse(200, {
          'status': 'success',
          'password': {'usable': true},
          'providers': [
            {'provider': 'google', 'usable': true, 'can_unlink': true},
          ],
          'recovery': {'codes_enrolled': false},
        });
      }
      if (request.method == 'POST') {
        return jsonResponse(200, {
          'status': 'success',
          'reauthentication_token': 'dummy-grant',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      }
      deletes++;
      return jsonResponse(500, {'status': 'error'});
    });
    final model = AccountAuthenticationController(
      repository: AuthManagementClient(
        authority: session,
        generation: generation,
        client: client,
      ),
      authority: session,
      generation: generation,
      continuity: AccountMethodsContinuity(
        generation,
        gate: session.state.reconciliation,
      ),
    );
    try {
      await model.refresh();
      await model.unlink('dummy-password');
      expect(deletes, 0);
      expect(model.writeBlocked, isTrue);
      expect(session.state.reconciliation, ReconciliationGate.storageBlocked);
      expect(store.value!.record!.marker, isNull);
    } finally {
      model.dispose();
      session.dispose();
      client.close();
    }
  });

  test(
    'last-method 409 clears only after valid GET and durable clear',
    () async {
      for (final outcome in [
        'valid',
        'server-error',
        'malformed',
        'clear-failure',
      ]) {
        final store = MarkerStoreFixture(
          StoredSession.managed(ActiveSessionRecord('dummy-jwt')),
        )..failMarkerClear = outcome == 'clear-failure';
        final session = SessionCoordinator(
          store: store,
          authentication: MarkerLoginFixture(),
        );
        await session.restore();
        final generation = session.snapshot().generation;
        var reads = 0;
        var deletes = 0;
        final client = MockClient((request) async {
          if (request.method == 'GET') {
            reads++;
            if (reads == 2 && outcome == 'server-error') {
              return jsonResponse(503, {
                'status': 'error',
                'code': 'server_error',
              });
            }
            if (reads == 2 && outcome == 'malformed') {
              return jsonResponse(200, {
                'status': 'success',
                'password': {'usable': 'wrong'},
                'providers': <Object>[],
                'recovery': {'codes_enrolled': false},
              });
            }
            return jsonResponse(200, {
              'status': 'success',
              'password': {'usable': true},
              'providers': [
                {'provider': 'google', 'usable': true, 'can_unlink': true},
              ],
              'recovery': {'codes_enrolled': false},
            });
          }
          if (request.method == 'POST') {
            return jsonResponse(200, {
              'status': 'success',
              'reauthentication_token': 'dummy-grant',
              'expires_at': '2099-01-01T00:00:00Z',
            });
          }
          if (request.method == 'DELETE') {
            deletes++;
            return jsonResponse(409, {
              'status': 'error',
              'code': 'last_authentication_method',
            });
          }
          return jsonResponse(500, {
            'status': 'error',
            'code': 'internal_error',
          });
        });
        final model = AccountAuthenticationController(
          repository: AuthManagementClient(
            authority: session,
            generation: generation,
            client: client,
          ),
          authority: session,
          generation: generation,
          continuity: AccountMethodsContinuity(
            generation,
            gate: session.state.reconciliation,
          ),
        );
        try {
          await model.refresh();
          await model.unlink('dummy-password');
          final cleared = outcome == 'valid';
          expect(model.writeBlocked, !cleared, reason: outcome);
          expect(store.value!.record!.marker == null, cleared, reason: outcome);
          expect(deletes, 1, reason: outcome);
          expect(model.message, isNot('Đã cập nhật phương thức đăng nhập.'));
          if (cleared) {
            expect(
              model.message,
              'Không thể gỡ phương thức đăng nhập cuối cùng.',
            );
          }
        } finally {
          model.dispose();
          session.dispose();
          client.close();
        }
      }
    },
  );

  test(
    'prepared Unlink without dispatch restores a locked methods graph',
    () async {
      final store = MarkerStoreFixture(
        StoredSession.managed(ActiveSessionRecord('dummy-jwt')),
      );
      final first = SessionCoordinator(
        store: store,
        authentication: MarkerLoginFixture(),
      );
      await first.restore();
      final lease = await first.prepareMutation(
        ReconciliationOperation.unlinkGoogle,
        first.snapshot().generation,
      );
      expect(store.value!.record!.marker, lease.marker);
      var gets = 0;
      var deletes = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          gets++;
          return jsonResponse(200, {
            'status': 'success',
            'password': {'usable': true},
            'providers': [
              {'provider': 'google', 'usable': true, 'can_unlink': true},
            ],
            'recovery': {'codes_enrolled': false},
          });
        }
        if (request.method == 'DELETE') deletes++;
        return jsonResponse(500, {'status': 'error'});
      });
      final restored = SessionCoordinator(
        store: store,
        authentication: MarkerLoginFixture(),
      );
      await restored.restore();
      final generation = restored.snapshot().generation;
      final model = AccountAuthenticationController(
        repository: AuthManagementClient(
          authority: restored,
          generation: generation,
          client: client,
        ),
        authority: restored,
        generation: generation,
        continuity: AccountMethodsContinuity(
          generation,
          gate: restored.state.reconciliation,
        ),
      );
      try {
        expect(model.writeBlocked, isTrue);
        await model.refresh();
        expect(model.writeBlocked, isTrue);
        expect(model.canUnlink, isFalse);
        expect(gets, 1);
        expect(deletes, 0);
        expect(store.value!.record!.marker, lease.marker);
      } finally {
        model.dispose();
        first.dispose();
        restored.dispose();
        client.close();
      }
    },
  );

  test(
    'durable Unlink lock survives a new coordinator and repeated methods reads',
    () async {
      final store = MarkerStoreFixture(
        StoredSession.managed(ActiveSessionRecord('dummy-jwt')),
      );
      final firstSession = SessionCoordinator(
        store: store,
        authentication: MarkerLoginFixture(),
      );
      await firstSession.restore();
      var reads = 0;
      var deletes = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/methods') {
          reads++;
          if (reads == 4) {
            return jsonResponse(503, {
              'status': 'error',
              'code': 'server_error',
            });
          }
          if (reads == 5) {
            return jsonResponse(200, {
              'status': 'success',
              'password': {'usable': 'wrong'},
              'providers': <Object>[],
              'recovery': {'codes_enrolled': false},
            });
          }
          return jsonResponse(200, {
            'status': 'success',
            'password': {'usable': true},
            'providers': reads == 6
                ? <Object>[]
                : [
                    {'provider': 'google', 'usable': true, 'can_unlink': true},
                  ],
            'recovery': {'codes_enrolled': false},
          });
        }
        if (request.url.path == '/api/auth/reauthentications') {
          return jsonResponse(200, {
            'status': 'success',
            'reauthentication_token': 'dummy-grant',
            'expires_at': '2099-01-01T00:00:00Z',
          });
        }
        expect(request.url.path, '/api/auth/social_identities/google');
        deletes++;
        return jsonResponse(200, {'status': 'success', 'code': 'not_linked'});
      });
      AccountAuthenticationController make(SessionCoordinator authority) {
        final generation = authority.snapshot().generation;
        return AccountAuthenticationController(
          repository: AuthManagementClient(
            authority: authority,
            generation: generation,
            client: client,
          ),
          authority: authority,
          generation: generation,
          continuity: AccountMethodsContinuity(
            generation,
            gate: authority.state.reconciliation,
          ),
        );
      }

      final first = make(firstSession);
      try {
        await first.refresh();
        await first.unlink('dummy-password');
        expect(first.writeBlocked, isTrue);
        expect(
          store.value!.record!.marker!.operation,
          ReconciliationOperation.unlinkGoogle,
        );
        first.dispose();
        firstSession
            .dispose(); // A new instance reads the same secure-session fixture.
        final restored = SessionCoordinator(
          store: store,
          authentication: MarkerLoginFixture(),
        );
        await restored.restore();
        final next = make(restored);
        try {
          expect(next.writeBlocked, isTrue);
          for (final expectedReads in [3, 4, 5]) {
            await next.refresh();
            expect(reads, expectedReads);
            expect(next.writeBlocked, isTrue);
            expect(next.canUnlink, isFalse);
            expect(deletes, 1);
          }
          await next.refresh();
          expect(reads, 6);
          expect(next.writeBlocked, isFalse);
          expect(store.value!.record!.marker, isNull);
          expect(deletes, 1);
        } finally {
          next.dispose();
          restored.dispose();
        }
      } finally {
        client.close();
      }
    },
  );

  test(
    'restored rotation warning needs valid methods and explicit acknowledgement',
    () async {
      final record = ActiveSessionRecord(
        'dummy-jwt',
        marker: ReconciliationMarker(
          ReconciliationOperation.rotateRecoveryCodes,
        ),
      );
      final store = MarkerStoreFixture(StoredSession.managed(record));
      final session = SessionCoordinator(
        store: store,
        authentication: MarkerLoginFixture(),
      );
      await session.restore();
      final generation = session.snapshot().generation;
      var gets = 0;
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method != 'GET') {
          writes++;
          return jsonResponse(500, {'status': 'error'});
        }
        gets++;
        if (gets == 1) {
          return jsonResponse(503, {'status': 'error', 'code': 'server_error'});
        }
        return jsonResponse(200, {
          'status': 'success',
          'password': {'usable': true},
          'providers': <Object>[],
          'recovery': {'codes_enrolled': true},
        });
      });
      final model = AccountAuthenticationController(
        repository: AuthManagementClient(
          authority: session,
          generation: generation,
          client: client,
        ),
        authority: session,
        generation: generation,
        continuity: AccountMethodsContinuity(
          generation,
          gate: session.state.reconciliation,
        ),
      );
      try {
        expect(model.lostCodes, isTrue);
        expect(model.writeBlocked, isTrue);
        await model.refresh();
        expect(model.writeBlocked, isTrue);
        expect(model.canAcknowledgeLostCodes, isFalse);
        await model.acknowledgeLostCodes();
        expect(store.value!.record!.marker, isNotNull);
        await model.refresh();
        expect(model.codes, isEmpty);
        expect(model.canAcknowledgeLostCodes, isTrue);
        expect(model.writeBlocked, isTrue);
        await model.acknowledgeLostCodes();
        expect(store.value!.record!.marker, isNull);
        expect(model.writeBlocked, isFalse);
        expect(writes, 0);
      } finally {
        model.dispose();
        session.dispose();
        client.close();
      }
    },
  );

  test(
    'pending Unlink read from old session cannot clear new session state',
    () async {
      final oldAuthority = TestAuthority();
      final newAuthority = TestAuthority();
      final oldContinuity = AccountMethodsContinuity(7);
      final newContinuity = AccountMethodsContinuity(7);
      final lateRead = Completer<http.Response>();
      var reads = 0;
      var deletes = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/methods') {
          reads++;
          if (reads == 3) return lateRead.future;
          return jsonResponse(200, {
            'status': 'success',
            'password': {'usable': true},
            'providers': [
              {'provider': 'google', 'usable': true, 'can_unlink': true},
            ],
            'recovery': {'codes_enrolled': false},
          });
        }
        if (request.url.path == '/api/auth/reauthentications') {
          return jsonResponse(200, {
            'status': 'success',
            'reauthentication_token': 'dummy-grant',
            'expires_at': '2099-01-01T00:00:00Z',
          });
        }
        deletes++;
        return jsonResponse(200, {'status': 'success', 'code': 'not_linked'});
      });
      final old = AccountAuthenticationController(
        repository: AuthManagementClient(
          authority: oldAuthority,
          generation: 7,
          client: client,
        ),
        authority: oldAuthority,
        generation: 7,
        continuity: oldContinuity,
      );
      final newer = AccountAuthenticationController(
        repository: AuthManagementClient(
          authority: newAuthority,
          generation: 7,
          client: client,
        ),
        authority: newAuthority,
        generation: 7,
        continuity: newContinuity,
      );
      var oldDisposed = false;
      try {
        await old.refresh();
        await old.unlink('dummy-password');
        expect(old.writeBlocked, isTrue);
        final stale = old.refresh();
        for (var attempt = 0; attempt < 100 && reads < 3; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(reads, 3);
        oldAuthority.current = false;
        old.dispose();
        oldContinuity.invalidate();
        oldDisposed = true;
        await newer.refresh();
        expect(newer.canUnlink, isTrue);
        expect(oldContinuity.writeBlocked, isFalse);
        lateRead.complete(
          jsonResponse(200, {
            'status': 'success',
            'password': {'usable': true},
            'providers': <Object>[],
            'recovery': {'codes_enrolled': false},
          }),
        );
        await stale;
        expect(newer.canUnlink, isTrue);
        expect(deletes, 1);
      } finally {
        if (!lateRead.isCompleted) {
          lateRead.complete(jsonResponse(503, {'status': 'error'}));
        }
        if (!oldDisposed) old.dispose();
        newer.dispose();
        client.close();
      }
    },
  );

  test(
    'lost rotation warning survives controller recreation without codes',
    () async {
      final repo = FakeRepository();
      final authority = TestAuthority();
      final continuity = AccountMethodsContinuity(7);
      final first = AccountAuthenticationController(
        repository: repo,
        authority: authority,
        generation: 7,
        continuity: continuity,
      );
      await first.refresh();
      await first.rotate('dummy-password');
      expect(first.codes, isNotEmpty);
      first.dispose();
      expect(first.codes, isEmpty);
      expect(continuity.lostCodes, isTrue);
      expect(continuity.writeBlocked, isTrue);
      final reopened = AccountAuthenticationController(
        repository: repo,
        authority: authority,
        generation: 7,
        continuity: continuity,
      );
      expect(reopened.lostCodes, isTrue);
      expect(reopened.canRotate, isFalse);
      await reopened.refresh();
      expect(reopened.writeBlocked, isTrue);
      expect(reopened.lostCodes, isTrue);
      expect(reopened.canRotate, isFalse);
      expect(repo.rotateCalls, 1);
      await reopened.acknowledgeLostCodes();
      expect(reopened.canRotate, isTrue);
      reopened.dispose();
      continuity.invalidate();
      expect(continuity.writeBlocked, isFalse);
      expect(continuity.lostCodes, isFalse);
    },
  );

  test('background clears prompt without a request on resume', () async {
    final repo = FakeRepository();
    final model = AccountAuthenticationController(
      repository: repo,
      authority: TestAuthority(),
      generation: 7,
    );
    await model.refresh();
    model.suspendForPrivacy();
    expect(model.codes, isEmpty);
    expect(model.privacySuspended, isTrue);
    model.resumeForPrivacy();
    expect(repo.reauthCalls, 0);
    expect(repo.rotateCalls, 0);
    expect(repo.methodsCalls, 1);
    model.dispose();
  });

  test(
    'background clears displayed codes and requires read plus acknowledgement',
    () async {
      final repo = FakeRepository();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      await model.refresh();
      await model.rotate('dummy-password');
      expect(model.codes, hasLength(10));
      model.suspendForPrivacy();
      expect(model.codes, isEmpty);
      expect(model.lostCodes, isTrue);
      expect(model.writeBlocked, isTrue);
      model.resumeForPrivacy();
      expect(repo.methodsCalls, 2);
      await model.refresh();
      expect(model.writeBlocked, isTrue);
      expect(model.canRotate, isFalse);
      await model.acknowledgeLostCodes();
      expect(model.canRotate, isTrue);
      expect(repo.rotateCalls, 1);
      model.dispose();
    },
  );

  test(
    'background before dispatch prevents mutation and uncertainty',
    () async {
      final repo = FakeRepository();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      await model.refresh();
      final before = Completer<void>();
      repo.beforeMutationDispatch = before;
      final operation = model.rotate('dummy-password');
      await Future<void>.delayed(Duration.zero);
      model.suspendForPrivacy();
      model.resumeForPrivacy();
      before.complete();
      await operation;
      expect(repo.rotateCalls, 0);
      expect(model.lostCodes, isFalse);
      expect(model.writeBlocked, isFalse);
      model.dispose();
    },
  );

  test('background during reauth discards late grant', () async {
    final repo = FakeRepository();
    final model = AccountAuthenticationController(
      repository: repo,
      authority: TestAuthority(),
      generation: 7,
    );
    await model.refresh();
    final pending = Completer<ReauthenticationGrant>();
    repo.pendingReauth = pending;
    final operation = model.rotate('dummy-password');
    model.suspendForPrivacy();
    model.resumeForPrivacy();
    pending.complete(
      ReauthenticationGrant(
        'dummy-grant',
        DateTime.now().add(const Duration(minutes: 4)),
        ReauthenticationPurpose.rotateRecoveryCodes,
      ),
    );
    await operation;
    expect(repo.rotateCalls, 0);
    expect(model.lostCodes, isFalse);
    model.dispose();
  });

  test(
    'background after rotation dispatch drops late codes without replay',
    () async {
      final repo = FakeRepository();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      await model.refresh();
      final pending = Completer<void>();
      repo.pendingMutation = pending;
      final operation = model.rotate('dummy-password');
      await Future<void>.delayed(Duration.zero);
      expect(repo.rotateCalls, 1);
      model.suspendForPrivacy();
      model.resumeForPrivacy();
      pending.complete();
      await operation;
      expect(model.codes, isEmpty);
      expect(model.lostCodes, isTrue);
      expect(model.writeBlocked, isTrue);
      expect(repo.rotateCalls, 1);
      model.dispose();
    },
  );

  test(
    'background after Unlink dispatch requires explicit reconciliation',
    () async {
      final repo = FakeRepository();
      final model = AccountAuthenticationController(
        repository: repo,
        authority: TestAuthority(),
        generation: 7,
      );
      await model.refresh();
      final pending = Completer<void>();
      repo.pendingMutation = pending;
      final operation = model.unlink('dummy-password');
      await Future<void>.delayed(Duration.zero);
      expect(repo.unlinkCalls, 1);
      model.suspendForPrivacy();
      model.resumeForPrivacy();
      pending.complete();
      await operation;
      expect(model.writeBlocked, isTrue);
      expect(model.canUnlink, isFalse);
      expect(repo.unlinkCalls, 1);
      await model.refresh();
      expect(model.methods?.google, isNull);
      expect(model.writeBlocked, isFalse);
      model.dispose();
    },
  );
}
