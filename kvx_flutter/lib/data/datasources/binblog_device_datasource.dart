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

  BinblogDeviceDataSource({
    required this.username,
    required this.password,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<List<Device>> getDevices() async {
    if (username.isEmpty || password.isEmpty) {
      throw const BinblogApiException('Chưa cấu hình tài khoản Binblog.');
    }

    final loginResponse = await _client.post(
      Uri.parse('$_baseUrl/api/login'),
      headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (loginResponse.statusCode != 200) {
      throw BinblogApiException(
        'Đăng nhập Binblog thất bại (${loginResponse.statusCode}).',
      );
    }

    final loginBody = _decodeObject(loginResponse.body);
    final token = loginBody['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const BinblogApiException('Binblog không trả về access token.');
    }

    final devicesResponse = await _client.get(
      Uri.parse('$_baseUrl/api/devices'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (devicesResponse.statusCode != 200) {
      throw BinblogApiException(
        'Không lấy được thiết bị (${devicesResponse.statusCode}).',
      );
    }

    final body = _decodeObject(devicesResponse.body);
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

  const BinblogApiException(this.message);

  @override
  String toString() => message;
}
