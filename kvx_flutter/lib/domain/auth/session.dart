import 'dart:math';

enum SessionPhase {
  unknown,
  restoring,
  signedOut,
  authenticating,
  authenticated,
}

enum SignOutReason { none, logout, expired, switching }

enum ReconciliationOperation { unlinkGoogle, rotateRecoveryCodes }

enum ReconciliationGate {
  unavailable,
  clean,
  legacy,
  corrupt,
  pendingUnlink,
  pendingRotation,
  storageBlocked,
}

String newLocalId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class ReconciliationMarker {
  final String operationId;
  final ReconciliationOperation operation;
  ReconciliationMarker(this.operation, {String? operationId})
    : operationId = operationId ?? newLocalId();

  @override
  bool operator ==(Object other) =>
      other is ReconciliationMarker &&
      other.operationId == operationId &&
      other.operation == operation;
  @override
  int get hashCode => Object.hash(operationId, operation);
}

class ActiveSessionRecord {
  final String token;
  final String sessionId;
  final ReconciliationMarker? marker;
  ActiveSessionRecord(this.token, {String? sessionId, this.marker})
    : sessionId = sessionId ?? newLocalId();

  ActiveSessionRecord replacing(ReconciliationMarker? next) =>
      ActiveSessionRecord(token, sessionId: sessionId, marker: next);

  @override
  bool operator ==(Object other) =>
      other is ActiveSessionRecord &&
      other.token == token &&
      other.sessionId == sessionId &&
      other.marker == marker;
  @override
  int get hashCode => Object.hash(token, sessionId, marker);
}

class MutationLease {
  final int generation;
  final String sessionId;
  final ReconciliationMarker marker;
  const MutationLease(this.generation, this.sessionId, this.marker);
}

enum MarkerResolution {
  provenNotDispatched,
  providerAbsent,
  lastMethodRejected,
  codesAcknowledged,
}

class SessionState {
  final SessionPhase phase;
  final int generation;
  final SignOutReason reason;
  final String? message;
  final bool clearing;
  final ReconciliationGate reconciliation;
  const SessionState({
    this.phase = SessionPhase.unknown,
    this.generation = 0,
    this.reason = SignOutReason.none,
    this.message,
    this.clearing = false,
    this.reconciliation = ReconciliationGate.unavailable,
  });
}

class StoredSession {
  final String? token;
  final ActiveSessionRecord? record;
  final bool quarantined;
  const StoredSession.active(String this.token)
    : record = null,
      quarantined = false;
  const StoredSession.signedOut()
    : token = null,
      record = null,
      quarantined = false;
  StoredSession.managed(this.record)
    : token = record?.token,
      quarantined = false;
  const StoredSession.quarantined(String this.token)
    : record = null,
      quarantined = true;
}

class SessionSnapshot {
  final String token;
  final int generation;
  const SessionSnapshot(this.token, this.generation);
}

enum SessionFailureKind { signedOut, stale, invalidToken, storage, login }

class SessionFailure implements Exception {
  final SessionFailureKind kind;
  const SessionFailure(this.kind);
  @override
  String toString() => switch (kind) {
    SessionFailureKind.signedOut => 'Vui lòng đăng nhập Binblog.',
    SessionFailureKind.stale => 'Phiên đăng nhập đã thay đổi.',
    SessionFailureKind.invalidToken =>
      'Binblog không trả về phiên đăng nhập hợp lệ.',
    SessionFailureKind.storage =>
      'Không lưu được thay đổi phiên. Phiên cũ có thể khôi phục khi mở lại ứng dụng. Hãy thử lại.',
    SessionFailureKind.login =>
      'Đăng nhập thất bại. Kiểm tra tài khoản và kết nối rồi thử lại.',
  };
}

enum AuthenticationAttemptFailureKind {
  userCancelled,
  providerFailure,
  providerConfigurationFailure,
  missingCredential,
  networkFailure,
  invalidProviderCredential,
  linkRequired,
  emailVerificationRequired,
  providerUnavailable,
  usernameUnavailable,
  malformedResponse,
  serverFailure,
}

class AuthenticationAttemptFailure implements Exception {
  final AuthenticationAttemptFailureKind kind;
  const AuthenticationAttemptFailure(this.kind);
  @override
  String toString() => switch (kind) {
    AuthenticationAttemptFailureKind.userCancelled => '',
    AuthenticationAttemptFailureKind.providerFailure =>
      'Không thể đăng nhập bằng Google. Hãy thử lại.',
    AuthenticationAttemptFailureKind.providerConfigurationFailure =>
      'Đăng nhập Google chưa được cấu hình cho bản dựng này.',
    AuthenticationAttemptFailureKind.missingCredential =>
      'Google không trả về thông tin đăng nhập hợp lệ. Hãy thử lại.',
    AuthenticationAttemptFailureKind.networkFailure =>
      'Không thể kết nối để đăng nhập. Kiểm tra mạng rồi thử lại.',
    AuthenticationAttemptFailureKind.invalidProviderCredential =>
      'Phiên Google không còn hợp lệ. Hãy đăng nhập Google lại.',
    AuthenticationAttemptFailureKind.linkRequired =>
      'Email này đã thuộc một tài khoản Binblog. Hãy đăng nhập bằng mật khẩu trước; ứng dụng sẽ không tự động liên kết tài khoản.',
    AuthenticationAttemptFailureKind.emailVerificationRequired =>
      'Tài khoản Google cần có email đã xác minh để đăng nhập.',
    AuthenticationAttemptFailureKind.providerUnavailable =>
      'Google tạm thời không khả dụng. Hãy thử lại sau.',
    AuthenticationAttemptFailureKind.usernameUnavailable =>
      'Chưa thể tạo tài khoản Binblog. Hãy thử lại sau.',
    AuthenticationAttemptFailureKind.malformedResponse ||
    AuthenticationAttemptFailureKind.serverFailure =>
      'Binblog chưa thể hoàn tất đăng nhập Google. Hãy thử lại sau.',
  };
}

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession value);
  Future<void> delete();
}

abstract interface class PasswordAuthenticator {
  Future<String> login(String username, String password);
}

abstract interface class GoogleCredentialProvider {
  Future<String> credential();
  Future<void> signOut();
}

abstract interface class SocialSessionExchanger {
  Future<String> exchange({
    required String provider,
    required String credential,
  });
}

abstract interface class SessionAccess {
  SessionSnapshot snapshot({int? expectedGeneration});
  bool isCurrent(int generation);
  Future<T> dispatch<T>(int generation, Future<T> Function() start);
  Future<bool> unauthorized(int generation);
}

abstract interface class ReconciliationAccess {
  ReconciliationGate reconciliationGate(int generation);
  MutationLease? pendingMutation(int generation);
  Future<MutationLease> prepareMutation(
    ReconciliationOperation operation,
    int generation,
  );
  Future<void> clearMutation(MutationLease lease, MarkerResolution resolution);
  Future<T> dispatchPrepared<T>(
    MutationLease lease,
    Future<T> Function() start,
  );
  Future<ReconciliationGate> refreshReconciliation(int generation);
}
