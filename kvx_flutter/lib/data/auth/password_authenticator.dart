import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/auth/session.dart';

class BinblogPasswordAuthenticator implements PasswordAuthenticator {
  final http.Client _client;
  BinblogPasswordAuthenticator(this._client);
  @override
  Future<String> login(String username, String password) async {
    final response = await _client
        .post(
          Uri.parse('https://khuonvien.vn/api/login'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const SessionFailure(SessionFailureKind.login);
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['token'] is! String ||
        (body['token'] as String).trim().isEmpty) {
      throw const SessionFailure(SessionFailureKind.invalidToken);
    }
    return body['token'] as String;
  }
}
