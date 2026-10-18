import 'dart:convert';
import 'package:http/http.dart' as http;

import '../auth/authenticated_transport.dart';

import '../../domain/entities/device.dart';
import '../models/binblog_device_dto.dart';
import 'device_local_datasource.dart';

class BinblogDeviceDataSource implements DeviceDataSource {
  static const _baseUrl = 'https://khuonvien.vn';
  final AuthenticatedTransport transport;
  BinblogDeviceDataSource({required this.transport});

  // The app owns transport/client lifetime; feature graphs never own credentials.
  void close() {}

  Future<Map<String, dynamic>> getJson(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final response = await transport.send(
      'GET',
      Uri.parse('$_baseUrl/$path').replace(queryParameters: query),
    );
    if (response.statusCode != 200) {
      throw _apiError(
        response,
        'Không tải được dữ liệu (${response.statusCode}). Hãy thử lại.',
      );
    }
    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    String? body,
    Set<int> successStatusCodes = const {200},
  }) async {
    final response = await transport.send(
      'POST',
      Uri.parse('$_baseUrl/$path'),
      body: body,
    );
    if (!successStatusCodes.contains(response.statusCode)) {
      final retry = int.tryParse(response.headers['retry-after'] ?? '') ?? 3;
      throw _apiError(response, 'Không gửi được lệnh.', retry.clamp(1, 60));
    }
    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required String body,
    Set<int> successStatusCodes = const {200},
  }) async {
    final response = await transport.send(
      'PUT',
      Uri.parse('$_baseUrl/$path'),
      body: body,
    );
    if (!successStatusCodes.contains(response.statusCode)) {
      throw _apiError(response, 'Không cập nhật được cấu hình.');
    }
    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await transport.send(
      'DELETE',
      Uri.parse('$_baseUrl/$path'),
    );
    if (response.statusCode != 200) {
      throw _apiError(response, 'Không cập nhật được cấu hình.');
    }
    return _decodeObject(response.body);
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

  BinblogApiException _apiError(
    http.Response response,
    String fallback, [
    int retryAfterSeconds = 3,
  ]) {
    String? code;
    String message = fallback;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        code = decoded['code'] as String?;
        message =
            decoded['message'] as String? ??
            decoded['error'] as String? ??
            fallback;
      }
    } catch (_) {}
    return BinblogApiException(
      message,
      statusCode: response.statusCode,
      retryAfterSeconds: retryAfterSeconds,
      code: code,
    );
  }
}

class BinblogApiException implements Exception {
  final String message;
  final int? statusCode;
  final int retryAfterSeconds;
  final String? code;

  const BinblogApiException(
    this.message, {
    this.statusCode,
    this.retryAfterSeconds = 3,
    this.code,
  });

  @override
  String toString() => message;
}
