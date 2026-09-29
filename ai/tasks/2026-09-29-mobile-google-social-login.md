# z8tvbhtth8 — Mobile Google Social Login

Implement Google sign-in for Swift and Flutter through the existing mobile
session foundation.

- Obtain a Google ID token only through an injectable platform adapter.
- Exchange only `provider: google` and `credential: <ID token>` with
  `POST /api/auth/social_sessions` over an unauthenticated client.
- Install and persist only the Binblog JWT returned by Rails.
- Preserve password login, durable logout, account-switch ordering, generation
  fencing, startup restore, and current-generation protected-request 401 rules.
- Keep Google cancellation quiet and map documented Rails errors to safe,
  provider-neutral authentication attempt failures.
- Use GoogleSignIn-iOS 9.0.0 and Flutter google_sign_in 7.2.0.
- Configure public OAuth identifiers at build time; never add client secrets.
- Do not implement Link/Unlink, Firebase, access-token login, auth-code exchange,
  provider auto-restore, or backend changes.

Real provider smoke requires deployed Rails social sessions and matching Web,
iOS, Android, and SHA configuration. Missing external configuration is reported
as BLOCKED BY CONFIG rather than an implementation failure.
