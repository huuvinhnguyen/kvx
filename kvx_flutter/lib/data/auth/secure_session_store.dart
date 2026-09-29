import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/auth/session.dart';

class SecureSessionStore implements SessionStore {
  static const _key = 'binblog.khuonvien.vn.session.v1';
  final FlutterSecureStorage _storage;
  const SecureSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
    ),
  }) : _storage = storage;
  @override
  Future<StoredSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    if (decoded['state'] == 'signedOut' && !decoded.containsKey('token')) {
      return const StoredSession.signedOut();
    }
    if (decoded['state'] == 'active' &&
        decoded['token'] is String &&
        (decoded['token'] as String).trim().isNotEmpty) {
      return StoredSession.active(decoded['token'] as String);
    }
    throw const SessionFailure(SessionFailureKind.storage);
  }

  @override
  Future<void> write(StoredSession value) => _storage.write(
    key: _key,
    value: jsonEncode({
      'version': 1,
      'state': value.token == null ? 'signedOut' : 'active',
      if (value.token != null) 'token': value.token,
    }),
  );
  @override
  Future<void> delete() => _storage.delete(key: _key);
}
