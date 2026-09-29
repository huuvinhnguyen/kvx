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
