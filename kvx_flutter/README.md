# kvx_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Binblog sessions

Run `flutter pub get`, then launch normally; build-time username/password defines
are not required. Sign in explicitly through the Binblog login screen. Sessions
persist with flutter_secure_storage 10.0.0. No startup validation request or
automatic reauthentication occurs. Account actions clear session-scoped screens.
A current-generation 401 requires explicit login; network/5xx errors retain auth.

See [the session decision](../docs/decisions/mobile-auth-session.md) and
[build/setup notes](../BUILD.md) for migration, logout failure behavior and checks.

## Google sign-in

Google login uses `google_sign_in` 7.2.0 and remains an explicit user action.
The plugin supplies a Google ID token to Rails; only the returned Binblog JWT is
installed in `SessionCoordinator` and secure storage. Password login remains
available, and startup never starts a Google flow.

Configure separate iOS and Android OAuth clients for the bundle/package IDs in
the build notes. Pass the shared backend Web OAuth client ID with
`--dart-define=GOOGLE_SERVER_CLIENT_ID=...`; Flutter iOS additionally reads its
client ID and reversed callback scheme from the xcconfig placeholders. Android
uses minSdk 24, the minimum supported by the resolved Android plugin. Never add
an OAuth client secret, Firebase, or `google-services.json`.

See [the Google login decision](../docs/decisions/mobile-google-social-login.md)
and [build/setup notes](../BUILD.md).
