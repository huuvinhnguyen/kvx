import 'session.dart';

enum ReauthenticationPurpose { rotateRecoveryCodes, unlinkIdentity }

extension ReauthenticationPurposeWire on ReauthenticationPurpose {
  String get wire => switch (this) {
    ReauthenticationPurpose.rotateRecoveryCodes => 'rotate_recovery_codes',
    ReauthenticationPurpose.unlinkIdentity => 'unlink_identity',
  };
}

class ProviderMethod {
  final String provider;
  final bool usable;
  final bool canUnlink;
  const ProviderMethod(this.provider, this.usable, this.canUnlink);
}

class AuthenticationMethods {
  final bool passwordUsable;
  final List<ProviderMethod> providers;
  final bool codesEnrolled;
  const AuthenticationMethods(
    this.passwordUsable,
    this.providers,
    this.codesEnrolled,
  );

  ProviderMethod? get google {
    for (final method in providers) {
      if (method.provider == 'google') return method;
    }
    return null;
  }

  bool get canUnlinkGoogle =>
      passwordUsable &&
      (google?.usable ?? false) &&
      (google?.canUnlink ?? false);
}

class ReauthenticationGrant {
  final String token;
  final DateTime expiresAt;
  final ReauthenticationPurpose purpose;
  bool _consumed = false;
  ReauthenticationGrant(this.token, this.expiresAt, this.purpose);

  bool usableFor(ReauthenticationPurpose expected, DateTime now) =>
      !_consumed && purpose == expected && now.isBefore(expiresAt);

  String? consumeFor(ReauthenticationPurpose expected, DateTime now) {
    if (!usableFor(expected, now)) return null;
    _consumed = true;
    return token;
  }
}

enum AccountAuthFailureKind {
  stale,
  cancelled,
  network,
  malformedResponse,
  authenticationRequired,
  invalidProviderCredential,
  malformedRequest,
  reauthenticationFailed,
  reauthenticationRequired,
  lastAuthenticationMethod,
  unsupportedMethod,
  unsupportedProvider,
  rateLimited,
  providerUnavailable,
  serverFailure,
  unknown,
  uncertain,
}

class AccountAuthFailure implements Exception {
  final AccountAuthFailureKind kind;
  const AccountAuthFailure(this.kind);

  bool get uncertainWrite => switch (kind) {
    AccountAuthFailureKind.network ||
    AccountAuthFailureKind.serverFailure ||
    AccountAuthFailureKind.malformedResponse ||
    AccountAuthFailureKind.uncertain => true,
    _ => false,
  };

  String get message => switch (kind) {
    AccountAuthFailureKind.authenticationRequired =>
      'Phiên Binblog đã hết hạn.',
    AccountAuthFailureKind.reauthenticationFailed => 'Mật khẩu không đúng.',
    AccountAuthFailureKind.reauthenticationRequired =>
      'Xác minh lại trước khi tiếp tục.',
    AccountAuthFailureKind.lastAuthenticationMethod =>
      'Không thể gỡ phương thức đăng nhập cuối cùng.',
    AccountAuthFailureKind.rateLimited =>
      'Thao tác quá nhanh. Hãy thử lại sau.',
    AccountAuthFailureKind.network =>
      'Không thể kết nối. Kiểm tra mạng rồi thử lại.',
    AccountAuthFailureKind.stale || AccountAuthFailureKind.cancelled => '',
    _ => 'Binblog chưa thể hoàn tất thao tác. Hãy thử lại sau.',
  };
}

abstract interface class AccountAuthRepository {
  Future<AuthenticationMethods> methods();
  Future<ReauthenticationGrant> reauthenticate(
    String password,
    ReauthenticationPurpose purpose,
  );
  Future<List<String>> rotateCodes(
    ReauthenticationGrant grant, {
    required MutationLease lease,
    required bool Function() beginDispatch,
  });
  Future<void> unlinkGoogle(
    ReauthenticationGrant grant, {
    required MutationLease lease,
    required bool Function() beginDispatch,
  });
  void cancel();
}
