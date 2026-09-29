import 'package:http/http.dart' as http;
import '../../domain/auth/session.dart';

class AuthenticatedTransport {
  final SessionAccess authority;
  final int generation;
  final http.Client client;
  const AuthenticatedTransport({
    required this.authority,
    required this.generation,
    required this.client,
  });
  Future<http.Response> send(String method, Uri url, {String? body}) async {
    final snapshot = authority.snapshot(expectedGeneration: generation);
    final request = http.Request(method, url);
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${snapshot.token}';
    if (method == 'POST') {
      request.headers['Content-Type'] = 'application/json';
      if (body != null) request.body = body;
    }
    http.Response response;
    try {
      response = await authority
          .dispatch(snapshot.generation, () async {
            final streamed = await client.send(request);
            return http.Response.fromStream(streamed);
          })
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      if (!authority.isCurrent(snapshot.generation)) {
        throw const SessionFailure(SessionFailureKind.stale);
      }
      rethrow;
    }
    if (!authority.isCurrent(snapshot.generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    if (response.statusCode == 401 &&
        !await authority.unauthorized(snapshot.generation)) {
      throw const SessionFailure(SessionFailureKind.stale);
    }
    return response;
  }
}
