import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvx_flutter/application/auth/google_sign_in_use_case.dart';
import 'package:kvx_flutter/application/auth/session_coordinator.dart';
import 'package:kvx_flutter/data/auth/social_session_client.dart';
import 'package:kvx_flutter/domain/auth/session.dart';
import 'package:kvx_flutter/main.dart';
import 'package:kvx_flutter/presentation/providers/session_provider.dart';
import 'package:kvx_flutter/presentation/screens/binblog_login_screen.dart';
import 'package:provider/provider.dart';
import 'session_test.dart' show FakeLogin, MemoryStore;

class FakeGoogleCredentials implements GoogleCredentialProvider {
  String token = 'google-id-token';
  Object? credentialError;
  bool failSignOut = false;
  int credentialCalls = 0;
  int signOutCalls = 0;
  Completer<String>? gate;
  Completer<void>? signOutGate;
  final signOutStarted = Completer<void>();

  @override
  Future<String> credential() async {
    credentialCalls++;
    if (credentialError case final Object error) throw error;
    return gate == null ? token : gate!.future;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (!signOutStarted.isCompleted) signOutStarted.complete();
    await signOutGate?.future;
    if (failSignOut) throw StateError('provider cleanup failed');
  }
}

class FakeSocialSessions implements SocialSessionExchanger {
  String token = 'binblog-session';
  Object? error;
  String? provider;
  String? credential;

  @override
  Future<String> exchange({
    required String provider,
    required String credential,
  }) async {
    this.provider = provider;
    this.credential = credential;
    if (error case final Object failure) throw failure;
    return token;
  }
}

void main() {
  group('social session HTTP contract', () {
    test(
      'sends only provider and credential and returns Binblog JWT',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/social_sessions');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'provider': 'google',
            'credential': 'google-id-token',
          });
          return http.Response(
            jsonEncode({
              'status': 'success',
              'token': 'binblog-session',
              'user': {
                'id': 1,
                'username': 'fixture',
                'email': 'f@example.com',
              },
            }),
            200,
          );
        });
        final subject = BinblogSocialSessionClient(
          client,
          endpoint: Uri.parse('https://test/api/auth/social_sessions'),
        );
        expect(
          await subject.exchange(
            provider: 'google',
            credential: 'google-id-token',
          ),
          'binblog-session',
        );
        client.close();
      },
    );

    const cases = <(int, String, AuthenticationAttemptFailureKind)>[
      (
        400,
        'malformed_request',
        AuthenticationAttemptFailureKind.malformedResponse,
      ),
      (
        401,
        'invalid_provider_credential',
        AuthenticationAttemptFailureKind.invalidProviderCredential,
      ),
      (409, 'link_required', AuthenticationAttemptFailureKind.linkRequired),
      (
        422,
        'unsupported_provider',
        AuthenticationAttemptFailureKind.providerFailure,
      ),
      (
        422,
        'email_verification_required',
        AuthenticationAttemptFailureKind.emailVerificationRequired,
      ),
      (
        503,
        'provider_unavailable',
        AuthenticationAttemptFailureKind.providerUnavailable,
      ),
      (
        503,
        'username_unavailable',
        AuthenticationAttemptFailureKind.usernameUnavailable,
      ),
      (500, 'internal_error', AuthenticationAttemptFailureKind.serverFailure),
    ];
    for (final (status, code, kind) in cases) {
      test('maps $status $code', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'status': 'error', 'code': code}),
            status,
          ),
        );
        final subject = BinblogSocialSessionClient(client);
        await expectLater(
          subject.exchange(provider: 'google', credential: 'credential'),
          throwsA(
            isA<AuthenticationAttemptFailure>().having(
              (error) => error.kind,
              'kind',
              kind,
            ),
          ),
        );
        client.close();
      });
    }

    test(
      'maps network and malformed success without returning a token',
      () async {
        final network = MockClient(
          (_) async => throw http.ClientException('offline'),
        );
        await expectLater(
          BinblogSocialSessionClient(
            network,
          ).exchange(provider: 'google', credential: 'credential'),
          throwsA(
            isA<AuthenticationAttemptFailure>().having(
              (error) => error.kind,
              'kind',
              AuthenticationAttemptFailureKind.networkFailure,
            ),
          ),
        );
        network.close();

        final malformed = MockClient(
          (_) async => http.Response('{"status":"success","token":""}', 200),
        );
        await expectLater(
          BinblogSocialSessionClient(
            malformed,
          ).exchange(provider: 'google', credential: 'credential'),
          throwsA(
            isA<AuthenticationAttemptFailure>().having(
              (error) => error.kind,
              'kind',
              AuthenticationAttemptFailureKind.malformedResponse,
            ),
          ),
        );
        malformed.close();
      },
    );
  });

  group('Google session integration', () {
    test('persists only returned Binblog JWT before authenticating', () async {
      final store = MemoryStore();
      final coordinator = SessionCoordinator(
        store: store,
        authentication: FakeLogin(),
      );
      final google = FakeGoogleCredentials();
      final sessions = FakeSocialSessions();
      final useCase = GoogleSignInUseCase(
        credentials: google,
        sessions: sessions,
      );
      await coordinator.restore();
      await coordinator.authenticate(useCase.execute);
      expect(sessions.provider, 'google');
      expect(sessions.credential, 'google-id-token');
      expect(store.writes.single.token, 'binblog-session');
      expect(store.writes.single.token, isNot('google-id-token'));
      expect(coordinator.snapshot().token, 'binblog-session');
      coordinator.dispose();
    });

    test('cancellation is preserved and installs nothing', () async {
      final store = MemoryStore();
      final coordinator = SessionCoordinator(
        store: store,
        authentication: FakeLogin(),
      );
      await coordinator.restore();
      await expectLater(
        coordinator.authenticate(
          () async => throw const AuthenticationAttemptFailure(
            AuthenticationAttemptFailureKind.userCancelled,
          ),
        ),
        throwsA(
          isA<AuthenticationAttemptFailure>().having(
            (error) => error.kind,
            'kind',
            AuthenticationAttemptFailureKind.userCancelled,
          ),
        ),
      );
      expect(coordinator.state.phase, SessionPhase.signedOut);
      expect(store.writes, isEmpty);
      coordinator.dispose();
    });

    test('missing credential never calls Rails or writes session', () async {
      final store = MemoryStore();
      final coordinator = SessionCoordinator(
        store: store,
        authentication: FakeLogin(),
      );
      final google = FakeGoogleCredentials()
        ..credentialError = const AuthenticationAttemptFailure(
          AuthenticationAttemptFailureKind.missingCredential,
        );
      final sessions = FakeSocialSessions();
      final useCase = GoogleSignInUseCase(
        credentials: google,
        sessions: sessions,
      );
      await coordinator.restore();

      await expectLater(
        coordinator.authenticate(useCase.execute),
        throwsA(
          isA<AuthenticationAttemptFailure>().having(
            (error) => error.kind,
            'kind',
            AuthenticationAttemptFailureKind.missingCredential,
          ),
        ),
      );
      expect(sessions.credential, isNull);
      expect(store.writes, isEmpty);
      expect(coordinator.state.phase, SessionPhase.signedOut);
      coordinator.dispose();
    });

    test('duplicate Google submit is rejected while first is active', () async {
      final coordinator = SessionCoordinator(
        store: MemoryStore(),
        authentication: FakeLogin(),
      );
      final google = FakeGoogleCredentials()..gate = Completer<String>();
      final useCase = GoogleSignInUseCase(
        credentials: google,
        sessions: FakeSocialSessions(),
      );
      await coordinator.restore();
      final pending = coordinator.authenticate(useCase.execute);
      while (google.credentialCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      await expectLater(
        coordinator.authenticate(useCase.execute),
        throwsA(
          isA<SessionFailure>().having(
            (error) => error.kind,
            'kind',
            SessionFailureKind.signedOut,
          ),
        ),
      );
      expect(google.credentialCalls, 1);
      expect(await coordinator.logout(), isTrue);
      google.gate!.complete('google-id-token');
      await expectLater(pending, throwsA(isA<SessionFailure>()));
      coordinator.dispose();
    });

    test('logout fences a late Google completion', () async {
      final store = MemoryStore();
      final coordinator = SessionCoordinator(
        store: store,
        authentication: FakeLogin(),
      );
      final google = FakeGoogleCredentials()..gate = Completer<String>();
      final useCase = GoogleSignInUseCase(
        credentials: google,
        sessions: FakeSocialSessions(),
      );
      await coordinator.restore();
      final pending = coordinator.authenticate(useCase.execute);
      while (google.credentialCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await coordinator.logout(), isTrue);
      google.gate!.complete('google-id-token');
      await expectLater(
        pending,
        throwsA(
          isA<SessionFailure>().having(
            (error) => error.kind,
            'kind',
            SessionFailureKind.stale,
          ),
        ),
      );
      expect(store.writes.map((value) => value.token), [null]);
      coordinator.dispose();
    });

    test('account switch fences a late Google completion', () async {
      final store = MemoryStore();
      final coordinator = SessionCoordinator(
        store: store,
        authentication: FakeLogin(),
      );
      final google = FakeGoogleCredentials()..gate = Completer<String>();
      final useCase = GoogleSignInUseCase(
        credentials: google,
        sessions: FakeSocialSessions(),
      );
      await coordinator.restore();
      final pending = coordinator.authenticate(useCase.execute);
      while (google.credentialCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      await coordinator.switchAccount('fixture', 'fixture');
      google.gate!.complete('google-id-token');

      await expectLater(
        pending,
        throwsA(
          isA<SessionFailure>().having(
            (error) => error.kind,
            'kind',
            SessionFailureKind.stale,
          ),
        ),
      );
      expect(coordinator.snapshot().token, 'session-B');
      expect(store.writes.map((value) => value.token), [null, 'session-B']);
      coordinator.dispose();
    });

    testWidgets(
      'cancellation shows no error and password login stays visible',
      (tester) async {
        final coordinator = SessionCoordinator(
          store: MemoryStore(),
          authentication: FakeLogin(),
        );
        final google = FakeGoogleCredentials()
          ..credentialError = const AuthenticationAttemptFailure(
            AuthenticationAttemptFailureKind.userCancelled,
          );
        final useCase = GoogleSignInUseCase(
          credentials: google,
          sessions: FakeSocialSessions(),
        );
        await tester.pumpWidget(
          KvxApp(
            coordinator: coordinator,
            client: MockClient((_) async => http.Response('{}', 200)),
            googleSignIn: useCase,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đăng nhập bằng Google'));
        await tester.pumpAndSettle();
        expect(find.text('Đăng nhập'), findsOneWidget);
        expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
        expect(
          find.byType(Text).evaluate().map((e) => (e.widget as Text).data),
          isNot(contains('Không thể đăng nhập bằng Google. Hãy thử lại.')),
        );
        await tester.pumpWidget(const SizedBox());
        coordinator.dispose();
      },
    );

    testWidgets(
      'delayed provider cleanup keeps password and Google login gated',
      (tester) async {
        final store = MemoryStore(const StoredSession.active('session'));
        final password = FakeLogin();
        final coordinator = SessionCoordinator(
          store: store,
          authentication: password,
        );
        final google = FakeGoogleCredentials()..signOutGate = Completer<void>();
        final useCase = GoogleSignInUseCase(
          credentials: google,
          sessions: FakeSocialSessions(),
        );
        final provider = SessionProvider(coordinator, googleSignIn: useCase);
        await coordinator.restore();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const MaterialApp(home: BinblogLoginScreen()),
          ),
        );

        final logout = provider.logout(reason: SignOutReason.switching);
        await google.signOutStarted.future;
        await tester.pump();

        expect(coordinator.state.phase, SessionPhase.signedOut);
        expect(store.value?.token, isNull);
        expect(provider.isSessionTransitioning, isTrue);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        await provider.login('other', 'password');
        await provider.loginWithGoogle();
        expect(password.calls, 0);
        expect(google.credentialCalls, 0);

        google.signOutGate!.complete();
        expect(await logout, isTrue);
        await tester.pump();
        expect(provider.isSessionTransitioning, isFalse);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull,
        );

        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        coordinator.dispose();
      },
    );

    test(
      'delayed provider cleanup failure leaves signed out then reenables login',
      () async {
        final store = MemoryStore(const StoredSession.active('session'));
        final password = FakeLogin();
        final coordinator = SessionCoordinator(
          store: store,
          authentication: password,
        );
        final google = FakeGoogleCredentials()
          ..failSignOut = true
          ..signOutGate = Completer<void>();
        final useCase = GoogleSignInUseCase(
          credentials: google,
          sessions: FakeSocialSessions(),
        );
        final provider = SessionProvider(coordinator, googleSignIn: useCase);
        await coordinator.restore();

        final logout = provider.logout();
        await google.signOutStarted.future;
        expect(store.value?.token, isNull);
        expect(coordinator.state.phase, SessionPhase.signedOut);
        expect(provider.isSessionTransitioning, isTrue);

        google.signOutGate!.complete();
        expect(await logout, isTrue);
        expect(provider.isSessionTransitioning, isFalse);
        expect(store.value?.token, isNull);
        expect(coordinator.state.phase, SessionPhase.signedOut);
        expect(google.signOutCalls, 1);

        await provider.login('other', 'password');
        expect(password.calls, 1);
        expect(coordinator.state.phase, SessionPhase.authenticated);
        provider.dispose();
        coordinator.dispose();
      },
    );
  });
}
