import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/application/auth/session_coordinator.dart';
import 'package:kvx_flutter/domain/auth/session.dart';
import 'package:kvx_flutter/main.dart';
import 'package:kvx_flutter/presentation/providers/session_provider.dart';
import 'session_test.dart' show MemoryStore, FakeLogin;

String devices(String name) => jsonEncode({
  'devices': [
    {
      'id': 64,
      'name': name,
      'chip_id': 'fixture',
      'device_type': 'pir',
      'status': 1,
    },
  ],
});
void main() {
  testWidgets('signed out startup waits for explicit login with no network', (
    tester,
  ) async {
    final login = FakeLogin();
    final coordinator = SessionCoordinator(
      store: MemoryStore(),
      authentication: login,
    );
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      return http.Response(devices('B device'), 200);
    });
    await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Binblog'), findsOneWidget);
    expect(calls, 0);
    expect(login.calls, 0);
    await tester.enterText(find.byType(TextField).at(0), 'fixture');
    await tester.enterText(find.byType(TextField).at(1), 'fixture');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(login.calls, 1);
    expect(find.text('Devices'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    client.close();
  });
  testWidgets('logout disposes account data and restart remains signed out', (
    tester,
  ) async {
    final store = MemoryStore(const StoredSession.active('A'));
    final login = FakeLogin();
    final coordinator = SessionCoordinator(store: store, authentication: login);
    final client = MockClient((r) async {
      expect(r.url.path, '/api/devices');
      expect(r.headers['Authorization'], 'Bearer A');
      return http.Response(devices('A device'), 200);
    });
    await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
    await tester.pumpAndSettle();
    expect(find.text('A device'), findsOneWidget);
    expect(login.calls, 0);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Binblog'), findsOneWidget);
    expect(find.text('A device'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    final restarted = SessionCoordinator(store: store, authentication: login);
    await tester.pumpWidget(KvxApp(coordinator: restarted, client: client));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Binblog'), findsOneWidget);
    expect(login.calls, 0);
    await tester.pumpWidget(const SizedBox());
    restarted.dispose();
    client.close();
  });
  testWidgets('logout removes an authenticated detail navigation route', (
    tester,
  ) async {
    final coordinator = SessionCoordinator(
      store: MemoryStore(const StoredSession.active('A')),
      authentication: FakeLogin(),
    );
    final client = MockClient(
      (r) async => http.Response(
        devices('A detail').replaceAll('"pir"', '"iphone"'),
        200,
      ),
    );
    await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A detail'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await coordinator.logout();
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Binblog'), findsOneWidget);
    expect(find.text('A detail'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    client.close();
  });
  for (final status in [200, 401]) {
    testWidgets('disposed A graph discards late $status after B login', (
      tester,
    ) async {
      final coordinator = SessionCoordinator(
        store: MemoryStore(const StoredSession.active('A')),
        authentication: FakeLogin(),
      );
      final oldResponse = Completer<http.Response>();
      final client = MockClient((r) async {
        if (r.headers['Authorization'] == 'Bearer A') return oldResponse.future;
        expect(r.headers['Authorization'], 'Bearer session-B');
        return http.Response(devices('B device'), 200);
      });
      await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
      await tester.pump();
      await tester.pump();
      await coordinator.switchAccount('fixture', 'fixture');
      await tester.pumpAndSettle();
      expect(find.text('B device'), findsOneWidget);
      oldResponse.complete(http.Response(devices('A device'), status));
      await tester.pumpAndSettle();
      expect(find.text('A device'), findsNothing);
      expect(find.text('B device'), findsOneWidget);
      expect(coordinator.state.phase, SessionPhase.authenticated);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      coordinator.dispose();
      client.close();
    });
  }
  testWidgets('401 shows expiry login without automatic authentication', (
    tester,
  ) async {
    final login = FakeLogin();
    final coordinator = SessionCoordinator(
      store: MemoryStore(const StoredSession.active('A')),
      authentication: login,
    );
    var requests = 0;
    final client = MockClient((r) async {
      requests++;
      return http.Response('{}', 401);
    });
    await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Binblog'), findsOneWidget);
    expect(
      find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
      findsOneWidget,
    );
    expect(login.calls, 0);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    client.close();
  });
  testWidgets('storage read failure offers retry without protected requests', (
    tester,
  ) async {
    final store = MemoryStore(const StoredSession.active('A'))..failRead = true;
    final coordinator = SessionCoordinator(
      store: store,
      authentication: FakeLogin(),
    );
    var requests = 0;
    final client = MockClient((r) async {
      requests++;
      return http.Response(devices('Recovered device'), 200);
    });
    await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(requests, 0);
    store.failRead = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered device'), findsOneWidget);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    client.close();
  });
  test(
    'disposed provider does not notify after pending login finishes',
    () async {
      final login = FakeLogin()..gate = Completer<String>();
      final coordinator = SessionCoordinator(
        store: MemoryStore(),
        authentication: login,
      );
      await coordinator.restore();
      final provider = SessionProvider(coordinator);
      var notifications = 0;
      provider.addListener(() {
        notifications++;
      });
      final pending = provider.login('fixture', 'fixture');
      await login.started.future;
      provider.dispose();
      final before = notifications;
      login.gate!.complete('B');
      await pending;
      expect(notifications, before);
      coordinator.dispose();
    },
  );
}
