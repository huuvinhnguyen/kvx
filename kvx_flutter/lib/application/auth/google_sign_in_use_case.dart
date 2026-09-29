import '../../domain/auth/session.dart';

class GoogleSignInUseCase {
  final GoogleCredentialProvider _credentials;
  final SocialSessionExchanger _sessions;
  const GoogleSignInUseCase({
    required GoogleCredentialProvider credentials,
    required SocialSessionExchanger sessions,
  }) : _credentials = credentials,
       _sessions = sessions;

  Future<String> execute() async {
    final credential = await _credentials.credential();
    return _sessions.exchange(provider: 'google', credential: credential);
  }

  Future<void> signOut() async {
    try {
      await _credentials.signOut();
    } catch (_) {
      // Binblog durable logout is authoritative; provider cleanup is best effort.
    }
  }
}
