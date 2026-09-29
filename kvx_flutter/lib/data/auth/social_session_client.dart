import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/auth/session.dart';

class BinblogSocialSessionClient implements SocialSessionExchanger {
  final http.Client _client;
  final Uri _endpoint;
  BinblogSocialSessionClient(this._client, {Uri? endpoint})
    : _endpoint =
          endpoint ??
          Uri.parse('https://khuonvien.vn/api/auth/social_sessions');

  @override
  Future<String> exchange({
    required String provider,
    required String credential,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'provider': provider, 'credential': credential}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.networkFailure,
      );
    } on http.ClientException {
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.networkFailure,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.malformedResponse,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.malformedResponse,
      );
    }
    if (response.statusCode == 200) {
      final token = decoded['token'];
      if (decoded['status'] != 'success' ||
          token is! String ||
          token.trim().isEmpty) {
        throw const AuthenticationAttemptFailure(
          AuthenticationAttemptFailureKind.malformedResponse,
        );
      }
      return token;
    }
    throw _map(response.statusCode, decoded['code']);
  }

  AuthenticationAttemptFailure _map(int status, Object? code) {
    final kind = switch ((status, code)) {
      (400, 'malformed_request') =>
        AuthenticationAttemptFailureKind.malformedResponse,
      (401, 'invalid_provider_credential') =>
        AuthenticationAttemptFailureKind.invalidProviderCredential,
      (409, 'link_required') => AuthenticationAttemptFailureKind.linkRequired,
      (422, 'unsupported_provider') =>
        AuthenticationAttemptFailureKind.providerFailure,
      (422, 'email_verification_required') =>
        AuthenticationAttemptFailureKind.emailVerificationRequired,
      (503, 'provider_unavailable') =>
        AuthenticationAttemptFailureKind.providerUnavailable,
      (503, 'username_unavailable') =>
        AuthenticationAttemptFailureKind.usernameUnavailable,
      (500, 'internal_error') => AuthenticationAttemptFailureKind.serverFailure,
      _ => AuthenticationAttemptFailureKind.malformedResponse,
    };
    return AuthenticationAttemptFailure(kind);
  }
}
