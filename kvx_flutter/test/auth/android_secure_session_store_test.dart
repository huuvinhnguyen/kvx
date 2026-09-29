import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/data/auth/secure_session_store.dart';
import 'package:kvx_flutter/domain/auth/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const store = SecureSessionStore();
  final calls = <MethodCall>[];
  var fail = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (fail) throw PlatformException(code: 'storage-failure');
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'production adapter disables Android destructive reset for every call',
    () async {
      expect(await store.read(), isNull);
      await store.write(const StoredSession.signedOut());
      await store.delete();
      expect(calls.map((call) => call.method), ['read', 'write', 'delete']);
      for (final call in calls) {
        expect((call.arguments as Map)['options']['resetOnError'], 'false');
      }
    },
  );

  test(
    'native read error is propagated rather than an absent session',
    () async {
      fail = true;
      await expectLater(store.read(), throwsA(isA<PlatformException>()));
      expect(calls, hasLength(1));
    },
  );

  test(
    'native write and delete errors propagate through the adapter',
    () async {
      fail = true;
      await expectLater(
        store.write(const StoredSession.active('synthetic-only')),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(store.delete(), throwsA(isA<PlatformException>()));
      expect(calls.map((call) => call.method), ['write', 'delete']);
    },
  );
}
