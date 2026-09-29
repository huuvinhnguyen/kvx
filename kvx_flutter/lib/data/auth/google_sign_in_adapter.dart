import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/auth/session.dart';

class GoogleSignInAdapter implements GoogleCredentialProvider {
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  final GoogleSignIn _signIn;
  Future<void>? _initialization;

  GoogleSignInAdapter({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  Future<void> _initialize() {
    if (defaultTargetPlatform == TargetPlatform.android &&
        _serverClientId.trim().isEmpty) {
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.providerConfigurationFailure,
      );
    }
    return _initialization ??= _signIn.initialize(
      serverClientId: _serverClientId.trim().isEmpty ? null : _serverClientId,
    );
  }

  @override
  Future<String> credential() async {
    try {
      await _initialize();
      if (!_signIn.supportsAuthenticate()) {
        throw const AuthenticationAttemptFailure(
          AuthenticationAttemptFailureKind.providerConfigurationFailure,
        );
      }
      final account = await _signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.trim().isEmpty) {
        throw const AuthenticationAttemptFailure(
          AuthenticationAttemptFailureKind.missingCredential,
        );
      }
      return token;
    } on AuthenticationAttemptFailure {
      rethrow;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthenticationAttemptFailure(
          AuthenticationAttemptFailureKind.userCancelled,
        );
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const AuthenticationAttemptFailure(
          AuthenticationAttemptFailureKind.providerConfigurationFailure,
        );
      }
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.providerFailure,
      );
    } catch (_) {
      throw const AuthenticationAttemptFailure(
        AuthenticationAttemptFailureKind.providerFailure,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _initialize();
    await _signIn.signOut();
  }
}
