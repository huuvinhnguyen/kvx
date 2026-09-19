import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/device.dart';
import '../models/binblog_device_dto.dart';
import 'device_local_datasource.dart';

class BinblogDeviceDataSource implements DeviceDataSource {
  static const _baseUrl = 'https://khuonvien.vn';
  final String username;
  final String password;
  final http.Client _client;
  String? _accessToken;
  Future<String>? _pendingLogin;

  Future<String> _token() async {
    if (_accessToken != null) return _accessToken!;
    final pending = _pendingLogin ??= _login();
    try {
      return await pending;
    } finally {
      if (identical(_pendingLogin, pending)) _pendingLogin = null;
    }
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, String> query,
  ) async {
    final token = await _token();
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/$path').replace(queryParameters: query),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) _accessToken = null;
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không tải được dữ liệu (${response.statusCode}). Hãy thử lại.',
        statusCode: response.statusCode,
      );
    }
    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> postJson(String path) async {
    final token = await _token();
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/$path'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) _accessToken = null;
    if (response.statusCode != 200) {
      final retry = int.tryParse(response.headers['retry-after'] ?? '') ?? 3;
      throw BinblogApiException(
        'Không gửi được lệnh.',
        statusCode: response.statusCode,
        retryAfterSeconds: retry.clamp(1, 60),
      );
    }
    return _decodeObject(response.body);
  }

  BinblogDeviceDataSource({
    required this.username,
    required this.password,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<String> _login() async {
    if (username.isEmpty || password.isEmpty) {
      throw const BinblogApiException('Chưa cấu hình tài khoản Binblog.');
    }

    final loginResponse = await _client
        .post(
          Uri.parse('$_baseUrl/api/login'),
          headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    if (loginResponse.statusCode != 200) {
      throw BinblogApiException(
        'Đăng nhập Binblog thất bại (${loginResponse.statusCode}).',
        statusCode: loginResponse.statusCode,
      );
    }

    final loginBody = _decodeObject(loginResponse.body);
    final token = loginBody['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const BinblogApiException('Binblog không trả về access token.');
    }

    _accessToken = token;
    return token;
  }

  @override
  Future<List<Device>> getDevices() async {
    final body = await getJson('api/devices', const {});
    final devices = body['devices'] as List<dynamic>? ?? const [];
    return devices
        .map(
          (item) => BinblogDeviceDto.fromJson(
            item as Map<String, dynamic>,
          ).toDomain(),
        )
        .toList();
  }

  @override
  Future<void> saveDevices(List<Device> devices) async {
    throw UnsupportedError('Binblog chưa cung cấp API ghi thiết bị.');
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const BinblogApiException('Binblog trả về dữ liệu không hợp lệ.');
    }
    return decoded;
  }
}

class BinblogApiException implements Exception {
  final String message;
  final int? statusCode;
  final int retryAfterSeconds;

  const BinblogApiException(
    this.message, {
    this.statusCode,
    this.retryAfterSeconds = 3,
  });

  @override
  String toString() => message;
}
