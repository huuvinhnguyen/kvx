import 'dart:convert';

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
      throw BinblogApiException(
        'Không tải được dữ liệu (${response.statusCode}). Hãy thử lại.',
        statusCode: response.statusCode,
      );
    }
    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> postJson(String path, {String? body}) async {
    final response = await transport.send(
      'POST',
      Uri.parse('$_baseUrl/$path'),
      body: body,
    );
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

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await transport.send(
      'DELETE',
      Uri.parse('$_baseUrl/$path'),
    );
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không cập nhật được cấu hình.',
        statusCode: response.statusCode,
      );
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
