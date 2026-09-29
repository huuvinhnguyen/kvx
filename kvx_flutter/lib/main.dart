import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'application/auth/session_coordinator.dart';
import 'application/auth/google_sign_in_use_case.dart';
import 'domain/auth/session.dart';
import 'data/auth/secure_session_store.dart';
import 'data/auth/password_authenticator.dart';
import 'data/auth/authenticated_transport.dart';
import 'data/auth/google_sign_in_adapter.dart';
import 'data/auth/social_session_client.dart';
import 'data/datasources/binblog_device_datasource.dart';
import 'data/repositories/binblog_buzzer_repository.dart';
import 'application/usecases/buzzer_usecases.dart';
import 'data/repositories/device_repository_impl.dart';
import 'application/usecases/device_usecases.dart';
import 'presentation/providers/device_provider.dart';
import 'presentation/providers/session_provider.dart';
import 'presentation/screens/device_list_screen.dart';
import 'presentation/screens/binblog_login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KvxApp());
}

class KvxApp extends StatefulWidget {
  final SessionCoordinator? coordinator;
  final http.Client? client;
  final http.Client? socialClient;
  final GoogleSignInUseCase? googleSignIn;
  const KvxApp({
    super.key,
    this.coordinator,
    this.client,
    this.socialClient,
    this.googleSignIn,
  });
  @override
  State<KvxApp> createState() => _KvxAppState();
}

class _KvxAppState extends State<KvxApp> {
  late final http.Client _client;
  late final http.Client _socialClient;
  late final SessionCoordinator _coordinator;
  late final SessionProvider _session;
  late final GoogleSignInUseCase _googleSignIn;
  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    _socialClient = widget.socialClient ?? http.Client();
    _coordinator =
        widget.coordinator ??
        SessionCoordinator(
          store: const SecureSessionStore(),
          authentication: BinblogPasswordAuthenticator(_client),
        );
    _googleSignIn =
        widget.googleSignIn ??
        GoogleSignInUseCase(
          credentials: GoogleSignInAdapter(),
          sessions: BinblogSocialSessionClient(_socialClient),
        );
    _session = SessionProvider(_coordinator, googleSignIn: _googleSignIn);
    unawaited(_session.restore());
  }

  @override
  void dispose() {
    _session.dispose();
    if (widget.coordinator == null) _coordinator.dispose();
    if (widget.client == null) _client.close();
    if (widget.socialClient == null) _socialClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _session,
    child: Consumer<SessionProvider>(
      builder: (context, session, _) {
        final state = session.state;
        if (state.phase == SessionPhase.authenticated) {
          return _AuthenticatedApp(
            key: ValueKey(state.generation),
            coordinator: _coordinator,
            generation: state.generation,
            client: _client,
          );
        }
        return MaterialApp(
          title: 'KVX',
          theme: _theme(),
          home:
              state.phase == SessionPhase.unknown ||
                  state.phase == SessionPhase.restoring
              ? Scaffold(
                  body: Center(
                    child: state.message == null
                        ? const CircularProgressIndicator(
                            semanticsLabel: 'Đang khôi phục phiên',
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.message!),
                              TextButton(
                                onPressed: session.restore,
                                child: const Text('Thử lại'),
                              ),
                              TextButton(
                                onPressed: () => session.logout(),
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                  ),
                )
              : const BinblogLoginScreen(),
        );
      },
    ),
  );
}

ThemeData _theme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,
);

class _AuthenticatedApp extends StatefulWidget {
  final SessionCoordinator coordinator;
  final int generation;
  final http.Client client;
  const _AuthenticatedApp({
    super.key,
    required this.coordinator,
    required this.generation,
    required this.client,
  });
  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
  late final BinblogDeviceDataSource _source;
  late final DeviceRepositoryImpl _repository;
  @override
  void initState() {
    super.initState();
    _source = BinblogDeviceDataSource(
      transport: AuthenticatedTransport(
        authority: widget.coordinator,
        generation: widget.generation,
        client: widget.client,
      ),
    );
    _repository = DeviceRepositoryImpl(_source);
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<BinblogDeviceDataSource>.value(value: _source),
      Provider<BuzzerUseCases>(
        create: (_) => BuzzerUseCases(BinblogBuzzerRepository(_source)),
      ),
      ChangeNotifierProvider(
        create: (_) => DeviceProvider(
          getDevicesUseCase: GetDevicesUseCase(_repository),
          addDeviceUseCase: AddDeviceUseCase(_repository),
          deleteDeviceUseCase: DeleteDeviceUseCase(_repository),
          toggleStatusUseCase: ToggleDeviceStatusUseCase(_repository),
        ),
      ),
    ],
    child: MaterialApp(
      title: 'KVX',
      theme: _theme(),
      home: const DeviceListScreen(),
    ),
  );
}
