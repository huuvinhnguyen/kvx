# z8tvbhuj25 — Debug Smoke Probe prerequisite verification

Date: 2026-10-12 (Asia/Ho_Chi_Minh). Scope: existing authenticated
`GET /api/auth/methods` on Swift iOS and Flutter iOS. This report verifies
prerequisite smoke evidence only. It does **not** complete account auth-recovery,
release its implementation, or change the Architect verdict from **BLOCKED**.

## Evidence boundary and contract

The Architect handoff specifies `GET https://khuonvien.vn/api/auth/methods`
with the current Binblog Bearer session. Its reviewed backend contract at
`68daae2a7c234f7cc308750413f718a28e9369ac` is HTTP 200 JSON with
`status: "success"`, `password.usable: bool`,
`providers: [{provider, usable: bool, can_unlink: bool}]`, and
`recovery.codes_enrolled: bool`. A success code is normally absent. The probe
reports principal match as NOT VERIFIED because the methods payload has no
principal identifier. `can_unlink` is advisory.

The matrix below transcribes the owner's screenshot summary dated 2026-10-12.
The screenshots and backend logs were not independently inspected in this
verification turn. `NR` means the owner summary did not report that field;
it does not mean an empty provider list.

| Platform | Owner-labeled fixture | Screenshot time (local) | Request ID | HTTP / JSON / status | Password usable | Providers | Codes enrolled | Principal | Contract comparison |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Swift iOS | Password session | NR | `dcca9447-2c75-40fc-a500-0bea77fb2bcc` | 200 / PASS / success | true | NR | false | NOT VERIFIED | Reported fields match; provider projection NR. |
| Swift iOS | Password session | NR | `af1db4d0-30f3-4e06-8a30-e71bc06eb85a` | 200 / PASS / success | true | NR | false | NOT VERIFIED | Reported fields match; provider projection NR. |
| Flutter iOS | Password session | NR | `de2cafa1-aa79-46b4-b3c4-f3773601e5fa` | 200 / PASS / success | true | NR | false | NOT VERIFIED | Reported fields match; provider projection NR. |
| Flutter iOS | Google session | 22:50:00 | `1710bb3d-736f-4d3e-9816-62d3c43b9f01` | 200 / PASS / success | false | google: usable=true, can_unlink=false | false | NOT VERIFIED | All reported required fields match. |
| Swift iOS | Google session | 22:51:27 | `23ed8065-eafd-450c-bdc0-d2e70180335b` | 200 / PASS / success | false | google: usable=true, can_unlink=false | false | NOT VERIFIED | All reported required fields match. |

The Google-session receipts support the authenticated methods read and expected
Google-only projection on both iOS apps at the receipt level. The password
receipts support the reported password and recovery fields, but their complete
provider arrays were not supplied. The owner also reports Google sign-in and
cold-start UI success on both iOS apps. HTTP 200, success UI, and these receipts
do not establish that the Binblog principal matches the owner-named account.
The owner's summary does not attest that the fixtures are disposable or show
backend correlation for any request ID.

## Evidence provenance and limits

- **Owner runtime evidence:** the five request IDs and allowlisted fields above;
  Google sign-in and cold-start UI success on Swift and Flutter iOS. No token,
  email, provider UID, user payload, or raw headers/body is included here.
- **Reviewer evidence from prior turns:** verdict **APPROVED FOR OWNER SMOKE**
  for the temporary probe after review of redirect, bounded receive,
  cancellation, generation fencing, allowlisting, and debug/opt-in gates.
  Reviewer reran Flutter focused tests (11/11), scoped analysis, and
  `git diff --check`; Swift focused rerun was interrupted by the simulator,
  while the Developer's earlier `.xcresult` showed 9/9 passed.
- **Developer evidence from prior turns:** Swift focused tests 9/9, Flutter
  focused tests 11/11 and analysis passed; opt-in Debug builds, ordinary Debug
  visibility checks, Release exclusion checks, effective Google plist/signing,
  and install-over-app checks were reported. The later owner-simulator rebuilds
  installed opt-in Swift and Flutter builds under unchanged bundle IDs with
  Google settings and valid ad-hoc signatures. These checks were not rerun here.
- **Source evidence inspected here:** the probe uses the fixed HTTPS GET,
  current session snapshot, generation checks, bounded allowlist receipt, and
  no principal assertion (`kvx/Debug/AuthMethodsSmokeProbe.swift` and
  `kvx_flutter/lib/debug/auth_methods_smoke_probe.dart`). The root insertions
  are debug/opt-in gated. Source and tests explain the receipt path; they do
  not independently verify the production principal or provider SDK storage.
- **Final Verifier this turn:** read the handoff/source, checked branch, HEAD,
  tracked diff, status, and whitespace. No API call, login, build, test, or
  runtime probe action was performed.

Google SDK-managed credential persistence is NOT VERIFIED. Provider
reauthentication is NOT IMPLEMENTED and was not smoked. Flutter Android smoke
is NOT RUN. The earlier Swift launch `EXC_BAD_ACCESS` in `os_log` remains
unexplained; successful later launches do not resolve it.

## Remaining dependencies and Architect reassessment

1. If principal match or fixture ownership must be established, a backend
   operator should privately correlate an allowlisted request ID with the
   owner-named disposable fixture and record a redacted MATCH/NOT VERIFIED
   attestation. Do not infer it from HTTP 200.
2. If a full password-fixture projection is needed, supply its allowlisted
   `providers[].provider/usable/can_unlink` values or record why they are not
   required. Confirm fixture history before interpreting any difference.
3. Architect should reconcile this iOS methods evidence with the remaining
   blocker exit criteria: exact deployed revision/schema and service evidence,
   approved recovery URL/mail and association behavior, effective runtime
   configuration, Android signing/OAuth evidence, safe fixtures and later smoke
   authorization. Existing handoff statements may need an evidence update;
   this report does not change them.
4. The handoff's real Google **reauthentication** acceptance evidence applies
   after that feature is implemented and authorized. Its absence must not be
   treated as a failed smoke of the existing Google login or this methods probe.
   Architect should explicitly separate implementation prerequisites from
   post-implementation acceptance evidence before releasing the main task.
5. Investigate the Swift `os_log` launch crash separately if it recurs. Do not
   label it fixed or unrelated based on a later successful launch.

The Architect alone reassesses readiness. Main auth-recovery remains BLOCKED.

## Temporary probe cleanup handoff — not executed

After the evidence has been retained and cleanup is authorized, remove only:

- `kvx/Debug/AuthMethodsSmokeProbe.swift` and
  `kvxTests/AuthMethodsSmokeProbeTests.swift`.
- The `#if DEBUG && AUTH_METHODS_PROBE` insertion in
  `kvx/Views/SessionRootView.swift` inside `AuthenticatedContent`. Restore the
  existing `ContentView` as that root's body without resetting other owner work.
- `kvx_flutter/lib/debug/auth_methods_smoke_probe.dart` and
  `kvx_flutter/test/auth/auth_methods_smoke_probe_test.dart`.
- The probe import, `package:flutter/foundation.dart` import if no longer used,
  and probe-only `Stack`/`Positioned` insertion in `kvx_flutter/lib/main.dart`.
- The Swift `AUTH_METHODS_PROBE` compiler opt-in (used through
  `OTHER_SWIFT_FLAGS='$(inherited) -D AUTH_METHODS_PROBE'`) and Flutter
  `--dart-define=AUTH_METHODS_PROBE=true` from local build commands.

Rebuild ordinary Debug with the existing Google OAuth settings, reinstall over
`com.kvx.kvx` and `com.kvx.kvxFlutter`, and verify the control is absent. Keep
the Architect handoff and this evidence report. Preserve the Google build
configuration, bundle identities, simulator app data, Keychain/secure store,
and unrelated owner changes. Do not uninstall or reset the simulator.

## Repository state at verification

Branch `feature/mobile-account-auth-recovery`; HEAD
`ecf548f8a0679e3f6bcd78beb6b5e2dbf770bfb0`. The pre-existing probe
changes remain in the two tracked roots and four untracked implementation/test
files; the Architect handoff remains untracked. This report is the only file
created by Final Verifier. No implementation file was edited, probe cleanup
performed, commit, push, PR, merge, or ClickUp update made.
