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

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession value);
  Future<void> delete();
}

abstract interface class PasswordAuthenticator {
  Future<String> login(String username, String password);
}

abstract interface class SessionAccess {
  SessionSnapshot snapshot({int? expectedGeneration});
  bool isCurrent(int generation);
  Future<T> dispatch<T>(int generation, Future<T> Function() start);
  Future<bool> unauthorized(int generation);
}
