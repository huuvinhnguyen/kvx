enum SessionPhase {
  unknown,
  restoring,
  signedOut,
  authenticating,
  authenticated,
}

enum SignOutReason { none, logout, expired, switching }

class SessionState {
  final SessionPhase phase;
  final int generation;
  final SignOutReason reason;
  final String? message;
  final bool clearing;
  const SessionState({
    this.phase = SessionPhase.unknown,
    this.generation = 0,
    this.reason = SignOutReason.none,
    this.message,
    this.clearing = false,
  });
}

class StoredSession {
  final String? token;
  const StoredSession.active(String this.token);
  const StoredSession.signedOut() : token = null;
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
