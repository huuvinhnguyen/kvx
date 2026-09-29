import 'package:http/http.dart' as http;
import 'package:kvx_flutter/domain/auth/session.dart';
import 'package:kvx_flutter/data/auth/authenticated_transport.dart';
import 'package:kvx_flutter/data/datasources/binblog_device_datasource.dart';

// Immutable authorization for existing DTO/endpoint fixtures. Session lifecycle
// tests use the real coordinator and persistence fakes instead.
class FixtureSession implements SessionAccess {
  final String token;
  const FixtureSession(this.token);
  @override
  SessionSnapshot snapshot({int? expectedGeneration}) =>
      SessionSnapshot(token, 1);
  @override
  bool isCurrent(int generation) => generation == 1;
  @override
  Future<T> dispatch<T>(int generation, Future<T> Function() start) => start();
  @override
  Future<bool> unauthorized(int generation) async => true;
}

BinblogDeviceDataSource authenticatedFixture({
  required http.Client client,
  String token = 'token',
}) => BinblogDeviceDataSource(
  transport: AuthenticatedTransport(
    authority: FixtureSession(token),
    generation: 1,
    client: client,
  ),
);
