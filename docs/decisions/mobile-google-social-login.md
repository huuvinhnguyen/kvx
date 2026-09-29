# Google Social Login — z8tvbhtth8

## Contract

Swift and Flutter use Google only to obtain a fresh ID token after an explicit
tap. A separate unauthenticated social-session client posts exactly `provider`
and `credential` to `POST /api/auth/social_sessions`. Rails verifies the token
and resolves the Binblog account. Clients do not trust or persist Google email,
profile, UID, access token, refresh token, or ID token.

The existing `SessionCoordinator` remains the only Binblog session owner. It
persists the Rails-issued JWT before publishing authenticated state. Its intent
revision fences duplicate operations and late provider/backend completions after
logout or account switching. Startup restores only the stored opaque Binblog
JWT and never starts Google SDK authentication.

The social endpoint does not use `AuthenticatedTransport`. Its 401 maps to an
invalid Google credential and cannot invalidate an existing Binblog session.
Documented backend codes map to provider-neutral authentication attempt errors.
Cancellation returns to signed out without a banner. `link_required` instructs
the user to access the existing account with password and never auto-links.

Durable Binblog logout completes before best-effort Google `signOut()`. Provider
cleanup failure cannot undo logout. Normal logout does not call `disconnect()`.
Link and Unlink remain outside this task.

## Platform integration

Swift uses the exact GoogleSignIn-iOS 9.0.0 SPM package products GoogleSignIn and
GoogleSignInSwift. The adapter runs on MainActor, validates the client/server IDs
and reversed URL scheme, performs interactive sign-in, refreshes tokens when
required, and returns `idToken.tokenString`. The app routes callback URLs to the
SDK. Signed simulator builds remain required for Keychain-backed sessions.

Flutter uses exact `google_sign_in: 7.2.0`, `GoogleSignIn.instance`, one lazy
initialization, and user-initiated `authenticate()`. It does not subscribe to
authentication events as application session state. The resolved Android plugin
requires minSdk 24, so the app declares 24. Direct Google Cloud configuration is
used without Firebase or the Google Services Gradle plugin.

Public OAuth client IDs enter through build configuration placeholders. One Web
client ID is the mobile `serverClientId` and Rails audience. Swift iOS, Flutter
iOS, and Flutter Android each use their own platform OAuth client; Android also
requires registered signing SHA certificates. No OAuth client secret belongs in
the mobile app or repository.

## Verification boundary

Unit/contract/widget tests use fake provider credentials and mock HTTP. They can
prove payloads, error mapping, coordinator ordering, cancellation, stale-result
fencing, and persistence boundaries; they do not prove a real Google or deployed
Rails flow. Native builds prove SDK/configuration compilation only.

Real smoke requires the backend URL with `/api/auth/social_sessions` deployed,
the backend Web audience, both iOS client IDs and reversed schemes, and the
Android OAuth client with the signing SHAs. Until supplied and configured, real
provider smoke is BLOCKED BY CONFIG.

## Developer verification — 2026-09-29

- Swift signed generic simulator app build: EXECUTED / PASSED.
- Swift signed `build-for-testing`, including all test targets and the focused
  Google suite: COMPILED ONLY. XCTest runtime launch was attempted on two iOS
  26.1 simulators with normal `test` and `test-without-building`; Xcode remained
  at `waiting for workers to materialize` before any test executed. Manual
  `simctl install` of the signed test host passed. No Swift runtime-test pass is
  claimed for this task.
- Flutter focused Google tests: EXECUTED / PASSED, 19/19, including delayed
  provider cleanup success and failure gates.
- Flutter related Google/session provider/widget tests: EXECUTED / PASSED,
  49/49. The previously verified complete-suite result was 120/120 before the
  targeted fix; the complete suite was not rerun for this follow-up.
- Flutter analyzer for touched auth/app/test scope: EXECUTED / PASSED.
- Flutter full analyzer: EXECUTED / FAILED with the existing 20 relay-demo and
  unrelated warnings/errors recorded by the session-foundation baseline; no
  issue is in the changed Google-auth scope.
- Flutter iOS simulator debug build: COMPILED ONLY / PASSED.
- Flutter Android debug APK build: COMPILED ONLY / PASSED.
- Canonical Dart formatting, plist lint, and git whitespace gates: EXECUTED /
  PASSED.
- Real Google SDK login with a Google ID token and deployed Rails exchange:
  BLOCKED BY CONFIG. The repository has no provider IDs, backend audience,
  Android signing SHA registrations, or confirmation that the production URL
  currently deploys `/api/auth/social_sessions`.
