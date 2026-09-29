import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kvx_flutter/main.dart';
import 'package:kvx_flutter/domain/auth/session.dart';
import 'package:kvx_flutter/application/auth/session_coordinator.dart';

class EmptyStore implements SessionStore {
  @override
  Future<StoredSession?> read() async => null;
  @override
  Future<void> write(StoredSession value) async {}
  @override
  Future<void> delete() async {}
}

class NoAutomaticLogin implements PasswordAuthenticator {
  int calls = 0;
  @override
  Future<String> login(String username, String password) async {
    calls++;
    throw StateError('Unexpected login');
  }
}

void main() {
  testWidgets(
    'Signed-out app shows explicit login and never sends startup HTTP',
    (tester) async {
      final authentication = NoAutomaticLogin();
      final coordinator = SessionCoordinator(
        store: EmptyStore(),
        authentication: authentication,
      );
      final client = MockClient((_) async {
        throw StateError('Unexpected startup request');
      });
      await tester.pumpWidget(KvxApp(coordinator: coordinator, client: client));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập Binblog'), findsOneWidget);
      expect(find.text('Devices'), findsNothing);
      expect(authentication.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
      client.close();
    },
  );
}
