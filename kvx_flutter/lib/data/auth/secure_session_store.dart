import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/auth/session.dart';

class SecureSessionStore implements SessionStore {
  static const _key = 'binblog.khuonvien.vn.session.v1';
  static final _id = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
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
    if (decoded is! Map<String, dynamic> || decoded['version'] is! int) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    if (decoded['version'] == 1) {
      if (decoded['state'] == 'signedOut' &&
          _keys(decoded, {'version', 'state'})) {
        return const StoredSession.signedOut();
      }
      if (decoded['state'] == 'active' &&
          _keys(decoded, {'version', 'state', 'token'}) &&
          decoded['token'] is String &&
          (decoded['token'] as String).trim().isNotEmpty) {
        return StoredSession.active(decoded['token'] as String);
      }
      throw const SessionFailure(SessionFailureKind.storage);
    }
    if (decoded['version'] != 2) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    if (decoded['state'] == 'signedOut') {
      if (!_keys(decoded, {'version', 'state'})) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      return const StoredSession.signedOut();
    }
    final token = decoded['token'];
    if (decoded['state'] != 'active' ||
        token is! String ||
        token.trim().isEmpty) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    final sessionId = decoded['session_id'];
    if (!_keys(decoded, {
          'version',
          'state',
          'token',
          'session_id',
          'marker',
        }) ||
        sessionId is! String ||
        !_id.hasMatch(sessionId)) {
      return StoredSession.quarantined(token);
    }
    final rawMarker = decoded['marker'];
    if (rawMarker == null) {
      return StoredSession.managed(
        ActiveSessionRecord(token, sessionId: sessionId),
      );
    }
    final marker = _parseMarker(rawMarker);
    if (marker == null) {
      return StoredSession.quarantined(token);
    }
    return StoredSession.managed(
      ActiveSessionRecord(token, sessionId: sessionId, marker: marker),
    );
  }

  @override
  Future<void> write(StoredSession value) async {
    if (value.quarantined) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
    final record = value.record;
    if (record != null) {
      if (record.token.trim().isEmpty || !_id.hasMatch(record.sessionId)) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      final marker = record.marker;
      if (marker != null && !_id.hasMatch(marker.operationId)) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'version': 2,
          'state': 'active',
          'token': record.token,
          'session_id': record.sessionId,
          'marker': marker == null ? null : _markerValue(marker),
        }),
      );
      return;
    }
    if (value.token != null) {
      if (value.token!.trim().isEmpty) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'version': 1,
          'state': 'active',
          'token': value.token,
        }),
      );
      return;
    }
    await _storage.write(
      key: _key,
      value: jsonEncode({'version': 2, 'state': 'signedOut'}),
    );
  }

  @override
  Future<void> delete() => _storage.delete(key: _key);

  static bool _keys(Map<String, dynamic> map, Set<String> expected) =>
      map.keys.toSet().containsAll(expected) && map.length == expected.length;

  static ReconciliationMarker? _parseMarker(Object value) {
    if (value is! Map<String, dynamic> ||
        value['version'] is! int ||
        value['version'] != 1 ||
        value['operation_id'] is! String ||
        !_id.hasMatch(value['operation_id'] as String)) {
      return null;
    }
    final id = value['operation_id'] as String;
    if (_keys(value, {
          'version',
          'operation_id',
          'operation',
          'provider',
          'reason',
        }) &&
        value['operation'] == 'unlink_google' &&
        value['provider'] == 'google' &&
        value['reason'] == 'await_provider_absence') {
      return ReconciliationMarker(
        ReconciliationOperation.unlinkGoogle,
        operationId: id,
      );
    }
    if (_keys(value, {'version', 'operation_id', 'operation', 'reason'}) &&
        value['operation'] == 'rotate_recovery_codes' &&
        value['reason'] == 'codes_receipt_at_risk') {
      return ReconciliationMarker(
        ReconciliationOperation.rotateRecoveryCodes,
        operationId: id,
      );
    }
    return null;
  }

  static Map<String, Object> _markerValue(ReconciliationMarker marker) =>
      switch (marker.operation) {
        ReconciliationOperation.unlinkGoogle => {
          'version': 1,
          'operation_id': marker.operationId,
          'operation': 'unlink_google',
          'provider': 'google',
          'reason': 'await_provider_absence',
        },
        ReconciliationOperation.rotateRecoveryCodes => {
          'version': 1,
          'operation_id': marker.operationId,
          'operation': 'rotate_recovery_codes',
          'reason': 'codes_receipt_at_risk',
        },
      };
}
