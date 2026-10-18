# Mobile Account Auth Recovery Architecture — z8tvbhuj25

## Verdict

**READY FOR SCOPED IMPLEMENTATION** of the password-backed, link-independent
account-management slice defined in the 2026-10-12 scope reconciliation below.
The full task and provider-dependent flows remain **BLOCKED**. This is not an
acceptance verdict or authorization for recovery-link work.
Owner approved the narrow nonsecret persistence exception on 2026-10-14.
The [durable reconciliation marker handoff](#durable-reconciliation-marker--owner-approved-2026-10-14)
is **READY FOR MARKER IMPLEMENTATION**. The current same-process fix and the
new marker still require independent Reviewer approval before owner mutation
smoke. This does not release the full task or Google provider-proof scope.

Owner deferred recovery-link integration to
[`z8tvbhvmvv`](https://app.clickup.com/t/z8tvbhvmvv). The linked follow-up is
To Do; its URL proposal is not approved. The current ClickUp description still
contains the old combined scope and is **not** amended by this document.

**Reassessed 2026-10-12.** Production checkout/migration/Web-process evidence,
the shared Google audience, four OAuth registrations, and owner-run Swift/Flutter
iOS login and authenticated-methods receipts close several earlier evidence
gaps. They do not approve a recovery URL, mail/Web behavior, or platform link
ownership. The minimum implementation blockers and staged exit criteria are in
[Readiness reassessment](#readiness-reassessment--2026-10-12). Historical
2026-10-11 findings and the original blocker checklist remain below for audit;
where they conflict, the new [scope reconciliation](#scope-reconciliation--2026-10-12)
controls. Its narrow release does not release the full task.

The temporary [Debug Smoke Probe](#debug-smoke-probe) was implemented, used by
the owner, removed, and its cleanup approved by Reviewer. Its handoff below is
a historical record, not an active request to rebuild the probe.

**Native-store gate update, 2026-10-17:** Flutter iOS native Keychain
verification remains **BLOCKED before marker logic**. The
[isolated diagnostic handoff](#flutter-native-keychain-blocker--2026-10-17)
releases one discriminating test-host experiment, not a dependency change or
owner mutation smoke. The dated marker implementation verdict above describes
authorization to write the marker code; it is not native-store acceptance.

## Flutter native Keychain blocker — 2026-10-17

**Decision: READY FOR ISOLATED DIAGNOSTIC ONLY; native-store acceptance remains
BLOCKED.** Do not repeat the ad hoc and manual-signing matrix already recorded
in `/private/tmp/kvx-native-marker-verify-20261016/flutter/VERIFICATION.md`.
The exact cause of the plugin's `SecItemAdd` `-34018` in the Flutter harness is
**not verified**. The failure is verified before `SessionCoordinator`, v2 record
decoding or marker preparation. Both iOS 18.1 and 26.1 simulator runs fail a
minimal plugin write. A Swift isolated Keychain harness passed process-restart
checks, but it ran in a different host. No Flutter native-store phase passed.

### Query and host comparison

| Property | Swift passing harness / `KeychainSessionStore` | Flutter pinned Darwin 0.2.0 with KVX `IOSOptions` | Diagnostic significance |
| --- | --- | --- | --- |
| Item identity | Generic password, explicit isolated service and account | Generic password, key as account; `accountName` maps to service. Although KVX does not set `accountName`, Dart `AppleOptions` defaults it to `flutter_secure_storage_service`; the earlier verification report's “no accountName” means no explicit override, **not** an absent service. | Unique-service and default-service plugin variants both failed; service spelling alone does not explain the result. |
| Group | No explicit `kSecAttrAccessGroup` | No `groupId`; plugin omits `kSecAttrAccessGroup` | On add, Apple uses the app's default entitled group when this attribute is absent. Do not insert an invented group. |
| Accessibility | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` in add/update attributes | Same protection requested, but plugin attempts `SecAccessControlCreateWithFlags(..., WhenUnlockedThisDeviceOnly, [])` even with no biometric flags; when creation succeeds it uses `kSecAttrAccessControl`. | **Concrete source-path delta and leading plugin-path hypothesis**, not proof of the runtime query or that the ACL causes `-34018`. |
| Synchronization | Explicit `kSecAttrSynchronizable=false` in query | Dart sends false, but Darwin 0.2.0's successful-ACL branch omits `kSecAttrSynchronizable` from the add query. | ThisDeviceOnly still forbids cloud sync; the missing attribute is a pinned-version behavior to compare, not permission to lower protection. |
| Add query | Value data plus class/service/account/sync/accessibility; no return-data request | `baseQuery` adds `kSecReturnData=true` even for `SecItemAdd`, then value data | Another query delta; isolate only if the two primary queries differ in result. |
| Platform conditional | iOS Security.framework | Plugin sets `kSecUseDataProtectionKeychain` only under `#if os(macOS)`, never in its iOS query | The macOS `usesDataProtectionKeychain:false` workaround is inapplicable to this iOS failure. |
| Host/signature | Separate isolated Swift simulator app passed | Flutter harness and installed KVX simulator artifact are ad hoc, have no effective entitlements/TeamIdentifier; their bundle IDs differ. Manual developer-signed harness with claimed restricted entitlements was rejected at launch. | Host/entitlement remains a competing cause. `codesign --verify` and an input `.entitlements` file do not establish that the simulator accepts those rights. |

Sources: local `kvx/Data/Auth/KeychainSessionStore.swift`,
`kvx_flutter/lib/data/auth/secure_session_store.dart`, pinned
`flutter_secure_storage-10.0.0/lib/options/apple_options.dart`, and
`flutter_secure_storage_darwin-0.2.0/.../FlutterSecureStorage{,DarwinPlugin}.swift`.
Apple calls `-34018` `errSecMissingEntitlement` and says to inspect the **built
app's effective signed entitlements and the actual query**, including default
group behavior ([Apple DTS guidance](https://developer.apple.com/forums/thread/114456)).
That establishes the status meaning, not which of the two host/query differences
caused this case. The pinned README requests iOS Keychain Sharing; an empty
entitlement array in the ad hoc build did not survive into the effective
signature, while manually asserted restricted entitlements caused launch
rejection. A provisioning profile is therefore one possible future requirement,
not a verified universal fix for the observed plugin-versus-Swift difference.

### Upstream applicability and production risk

The [Darwin plugin changelog](https://github.com/juliansteenbakker/flutter_secure_storage/blob/develop/flutter_secure_storage_darwin/CHANGELOG.md)
states that 0.3.0 stopped dropping `kSecAttrSynchronizable` when no access
control flags are present. [Current upstream source](https://github.com/juliansteenbakker/flutter_secure_storage/blob/develop/flutter_secure_storage_darwin/darwin/flutter_secure_storage_darwin/Sources/flutter_secure_storage_darwin/FlutterSecureStorage.swift)
shows the corresponding guard: without flags it skips `SecAccessControl` and
uses the ordinary accessibility attribute. This code delta directly addresses
the query difference above, but upstream does **not** establish that it fixes
this harness's `-34018`. The same changelog records a 0.4.1 compatibility fix:
0.3.0-style reads missed pre-0.3.0 ACL-envelope items, with subsequent writes
possibly failing `errSecDuplicateItem`; the [upstream iOS report](https://github.com/juliansteenbakker/flutter_secure_storage/issues/1158)
includes affected 10.0.0-to-10.1.0 upgrades. Any dependency change requires
owner approval and a separate existing-item read/migration and rollback review.
The 0.3.2 `kSecUseDataProtectionKeychain` note is macOS-only for this path.

The production KVX Flutter artifact has the same pinned plugin and ad hoc
effective-signature shape, so native storage there is **NOT VERIFIED**; it is
not proven broken. Owner-observed UI login and cold-start restore do not
identify a successful native secure-store write/read. Do not read the real
session item or infer Keychain behavior from the authenticated screen. The
Flutter native-store gate, production mutation smoke, and physical-device /
power-loss evidence remain respectively BLOCKED, prohibited, and NOT VERIFIED.

### One minimal discriminating experiment

Use the existing **isolated Flutter harness** outside the repository, on one
already available simulator runtime. Keep its distinct bundle/container and
fresh, harness-only service/account names. Add one native, one-shot Security
diagnostic to that same Runner process or its `RunnerTests` hosted by that
Runner; do not use the production `com.kvx.kvxFlutter` RunnerTests host. Before
install, record bundle ID, signing mode and *effective* `codesign -d
--entitlements :-` result for this exact artifact. Do not claim a default
group when the signature shows none. No production group, session key, JWT,
coordinator, API client or real credentials participate.

1. In one unchanged host/signature, call `SecItemAdd` with **A**, the passing
   Swift-shaped generic-password query: unique test service/account, dummy
   value, `WhenUnlockedThisDeviceOnly`, `synchronizable:false`, no explicit
   access group or return-data key. Record only operation label and OSStatus;
   read/delete that exact item if A succeeds.
2. With a second unique test item in the same process, call **B**, the pinned
   Darwin-0.2.0-shaped add query: same class/protection, its empty-flags
   `SecAccessControl`, omitted sync attribute, `kSecReturnData=true`. If A and
   B differ, use at most two one-factor local variants (ACL versus ordinary
   accessibility, then return-data) to identify the responsible key. Record
   only labels/statuses; delete exact successful test items.
3. Only if the native pair warrants it, make one existing minimal Dart plugin
   write/read/delete using a third unique dummy key, and record plugin result.
   Keep the plugin dependency and production adapter unchanged. Bound every
   launch/test, terminate the harness process and remove only harness items and
   bundle/container afterward. Never print query values, record bytes, token,
   access-group identifiers or raw plugin errors.

Interpretation: **A fails with `-34018`** means the identical host cannot run
the Swift-shaped query, so prioritize a supported isolated test-host signing
path; plugin changes are not established. **A succeeds, B fails** isolates a
query behavior; a local test-only delta may then confirm the exact attribute,
but no production patch/upgrade follows automatically. **A and B succeed but
plugin fails** points to option serialization or plugin invocation and calls
for native-entry-point inspection. **All succeed** permits the existing dummy
v2 prepare → real process terminate/relaunch → lock → conditional clear →
relaunch clean → durable logout → relaunch signed-out matrix, with native
plugin/store and fake network clients. None of these outcomes alone proves
power-loss atomicity or production signing.

If A fails, the next host candidate is a cloned, isolated Xcode `RunnerTests`
host or Apple-supported simulator signing workflow that actually launches
with a verified default group. The existing `RunnerTests` target is hosted by
the **production** Runner and is unsuitable without cloning; merely changing
the test bundle ID does not isolate the host's Keychain. Do not create a fake
Team ID, claim a shared group, retry manual restricted entitlements rejected
by `launchd_sim`, disable security checks, or use a macOS-only option. If no
such host can be signed locally, document that specific toolchain/signing
blocker and return to Architect/owner; do not waive the native gate.

**Implementation scope and rollback:** This releases only temporary harness
code/config and allowlisted receipts under `/private/tmp/kvx-native-marker-verify-20261016`.
No production source, plugin patch, dependency, bundle ID, storage key or
security policy change is approved. Remove the diagnostic and only its isolated
items/container when done; preserve existing KVX app data and Keychain. If a
plugin change later becomes necessary, propose its exact iOS query delta,
pre-0.3.0 record compatibility, logout/restore behavior, Android impact,
rollback and focused native regression tests to owner first. Reviewer must
verify same-process locking, durable marker and actual native-store evidence
before owner mutation smoke. Main auth-recovery and Google proof remain blocked.

#### Ready-to-copy Developer prompt — isolated diagnostic only

```text
Bạn là Developer Agent trong /Users/vinhnguyen/Documents/kvx.
Chỉ thực hiện “One minimal discriminating experiment” trong mục “Flutter
native Keychain blocker — 2026-10-17” của Architect handoff. Giữ production
tree/app/session nguyên vẹn. Dùng đúng isolated Flutter harness, cùng một
simulator host/signature, dummy items và native Security.framework A/B query;
ghi allowlisted OSStatus, effective signed entitlements và cleanup receipt.
Chỉ chạy plugin minimal probe và marker process-restart matrix nếu các bước
trước đủ điều kiện. Không lặp signing matrix, không đổi dependency/production
config, không đụng session thật, không gửi API hoặc mutation. Báo kết quả mỗi
nhánh và chuyển Reviewer; native gate vẫn BLOCKED đến khi được review.
```

## Scope reconciliation — 2026-10-12

Owner deferred link integration to linked ClickUp follow-up
[`z8tvbhvmvv — Recovery links`](https://app.clickup.com/t/z8tvbhvmvv).
Read-only ClickUp inspection on 2026-10-12 confirmed that `z8tvbhuj25` still
has its original description and the follow-up is To Do, Normal priority, with
no due date. The task link is an association, not evidence that either task is
complete or that the draft `/account/recovery` URL is approved. The earlier
[readiness reassessment](#readiness-reassessment--2026-10-12) is a dated snapshot;
its recovery-link blockers now apply to the follow-up, not to the independent
slice released below. The verification report is unchanged.

### Capability and dependency matrix

| Capability | Task and current release | Real dependency | Acceptance |
| --- | --- | --- | --- |
| Auth methods state and screen | `z8tvbhuj25`: **READY** | Existing Binblog session and deployed `GET /api/auth/methods`; no recovery URL. | Typed complete projection, safe loading/error/empty states, server `can_unlink` advisory, generation fencing; iOS owner receipts are prerequisite evidence, not final UI acceptance. |
| Specialized auth-management client/error mapping | `z8tvbhuj25`: **READY** | Current session authority and reviewed backend contract; no SDK or link route. | Only parsed current-generation `401 authentication_required` expires; malformed/other 401, timeout, 5xx and stale responses preserve the valid session; bounded decoding and redacted diagnostics. |
| Password reauthentication | `z8tvbhuj25`: **READY** for password-enabled accounts | Existing password method and purpose-bound backend grant. | Explicit password entry; grant bound to purpose/JWT and held in operation memory only; wrong/cancel/expiry leaves session usable. |
| Recovery-code enrollment/rotation | `z8tvbhuj25`: **READY** only via password reauthentication; Google-only path remains gated within this task | `POST /api/auth/recovery_codes`, purpose `rotate_recovery_codes`; no mail link. Google-only fixture needs provider reauth. | One-time display, acknowledgement/clear, no raw-code persistence or replay after lost response; `codes_enrolled` cannot recover code values. Google-only acceptance waits for provider decision. |
| First-password setup | `z8tvbhuj25`: **BLOCKED sub-scope**, not transferred | A no-password Google-only account requires Google reauthentication for `add_password`; username and backend grant. | After provider gate, reconcile `password.usable`, prove password login on disposable fixture; no recovery link needed. |
| Provider reauthentication | `z8tvbhuj25`: **BLOCKED sub-scope**, not transferred | Explicit fresh Google proof, SDK lifecycle decision below, deployed `POST /api/auth/reauthentications`. | Backend accepts a purpose-bound grant; cancel/failure/wrong identity preserves Binblog session; no app-owned proof/grant persistence and approved SDK persistence policy. Real smoke follows code. |
| Link Google | `z8tvbhuj25`: **BLOCKED sub-scope**, not transferred | Password or Google reauth grant plus fresh Google credential; provider gate. No external Link URL. | Principal unchanged; conflict, invalid credential, timeout and reconciliation handled without replay. |
| Unlink Google | `z8tvbhuj25`: **READY** only for password-enabled mixed accounts using password reauth; Google-only path remains gated | `DELETE /api/auth/social_identities/google` and `unlink_identity` grant; no link infrastructure. | Server last-method refusal is authoritative; success/uncertain results reconcile methods; never remove sole usable method. |
| Server-state reconciliation, single-operation gate and generation fencing | `z8tvbhuj25`: **READY** | Existing SessionCoordinators and methods endpoint. | No stale result/expiry after logout or switch; uncertain mutation blocks further writes until authoritative refresh; no automatic replay. |
| Public recovery initiation and token completion UX | [`z8tvbhvmvv`](https://app.clickup.com/t/z8tvbhvmvv): **DEFERRED** | Mail URL, browser/mobile entry and token handoff must be approved together; do not ship an initiation screen that leads to an unowned completion path. | Generic accepted response; password and social recovery remain distinct in backend authorization, return no JWT, require explicit login. No manual token-paste substitute is authorized. |
| Recovery mail URL conversion, cold/warm/duplicate routing, browser fallback and Swift/Flutter app selection | [`z8tvbhvmvv`](https://app.clickup.com/t/z8tvbhvmvv): **DEFERRED** | Versioned product/backend/mobile URL contract and working Web fallback. | Both mail variants, signed-in isolation, app-absent behavior, invalid/expired/duplicate cases and two iOS apps installed are tested. |
| Apple Team ID, signing/host association, AASA/assetlinks publication and end-to-end link/mail smoke | [`z8tvbhvmvv`](https://app.clickup.com/t/z8tvbhvmvv): **DEFERRED** | Accepted signing identities, domain ownership, mail environment and controlled inboxes. | Published path-scoped associations verify on accepted devices; delivered links complete correct flows without token leakage. |

The current task may finish its independent account-management capability only
after the blocked Google sub-scope is resolved and its acceptance passes. The
follow-up owns the deferred integration and its security requirements; completing
this task cannot be interpreted as completing recovery links. Keep the approved
backend contract, session invariants, platform parity and all safety tests.

### Process-restart reconciliation policy — 2026-10-13 (historical decision request)

This section records the pre-approval options. The 2026-10-14
[durable marker handoff](#durable-reconciliation-marker--owner-approved-2026-10-14)
supersedes its BLOCKED verdict and proposed owner decision. Its backend
evidence and distinction between session, graph and operation lifetimes remain
applicable.

**Policy verdict: BLOCKED — owner decision required.** The current in-process
Unlink/lost-rotation continuity fix is awaiting independent Reviewer re-review;
Developer reports Swift 23/23 and Flutter 37/37 focused tests and affected Debug
builds passing. Those checks cover screen recreation in one authenticated graph,
not process death. Do not approve owner mutation smoke or call the scoped slice
accepted on this basis. This gate does not revoke the dated authorization to
implement the independent slice or release blocked Google/link sub-scopes.

#### Distinct lifetimes and available evidence

- A **Binblog authentication session** is the JWT held by the existing secure
  session store. Swift and Flutter `SessionCoordinator.restore` load it after
  process start, then assign a new *local* generation. Restarting the app is
  neither logout nor session termination when that JWT is restored. A generation
  number is not a stable identifier across process lifetimes.
- An **authenticated graph** is Swift `AuthenticatedContent` or Flutter
  `_AuthenticatedApp`, keyed to the current local generation. Its
  `AccountMethodsContinuity` contains only pending Unlink provider, refresh
  requirement and lost-code warning. It survives screen/controller recreation,
  but process death destroys it; a restored JWT creates a fresh empty graph.
- A **reconciliation operation** begins at a potentially dispatched mutation
  and ends only when its contract-specific authoritative condition is met or
  the Binblog session ends. For Unlink, a fully decoded current-session methods
  projection must show the provider absent. `200 unlinked/not_linked`, a new
  password grant, another GET showing Google, and process death do not resolve
  a contradictory pending Unlink. For lost rotation, `codes_enrolled` can report
  enrollment but cannot recover the raw codes or prove whether a lost receipt
  was displayed/saved. Keep the warning and require explicit acknowledgement
  before any fresh rotation, always with a new grant.

The reviewed backend contract at `68daae2a7c234f7cc308750413f718a28e9369ac`
documents `DELETE /api/auth/social_identities/google` with `unlinked/not_linked`
and `GET /api/auth/methods` with method state. It documents no operation ID,
idempotency key, durable mutation receipt, receipt lookup, or recoverable raw-code
endpoint. No backend source checkout or live API was rechecked in this policy
turn; an undocumented mechanism is **NOT VERIFIED**. Backend last-method
protection and principal authorization still govern every DELETE, but they do
not reconstruct a lost client reconciliation reason or make replay safe.

#### Options and recommendation

| Option | Safety and availability | Decision boundary |
| --- | --- | --- |
| Keep process-only metadata; after restore do a fresh GET, fresh grant and acknowledgement | **Insufficient for the existing Unlink invariant.** A present Google provider does not reveal the prior `not_linked` contradiction. A fresh grant authorizes a new attempt; it proves nothing about the old write. Lost-code warning also vanishes. | Requires owner to narrow the invariant to graph lifetime and accept this bypass. Do not adopt implicitly. |
| Conservatively block account mutations on **every restored JWT** until explicit logout/new login, with no added persistence | Preserves the strict boundary even when the client cannot distinguish pending from clean sessions. Normal cold starts lose account-management writes; GET and acknowledgement alone cannot selectively unlock a Google-present session. No automatic logout. | Possible temporary fail-closed policy only with owner-approved availability/acceptance change; it is not implemented. |
| Persist a small **nonsecret, session-bound pending marker** before mutation dispatch | Recommended for the current scoped flow if owner approves a narrow persistence exception. Marker survives restart; Unlink still waits for valid provider absence or session end. Lost rotation still requires valid GET, warning and owner acknowledgement. A crash after marker write but before dispatch can cause a false-positive lock. | Changes the current “Only the Binblog JWT is persisted” requirement and secure-store schema/transaction boundary. **Owner/security approval required before implementation.** |
| Add backend operation receipt/idempotency evidence | Can distinguish outcome across process/device if designed and deployed correctly, with no client pending metadata persistence. No such contract exists in the reviewed handoff. | Requires separate backend contract, implementation, deployment and acceptance evidence; not authorized in this mobile slice. |

**Recommended owner decision:** permit only a versioned, nonsecret pending marker
bound to the existing secure Binblog session record. It may contain an operation
kind (`unlink_google` or `rotation_receipt_at_risk`), provider identifier for
Unlink, and a session-record binding; it must contain **no** JWT or JWT-derived
identifier in logs, password, grant, raw code, provider credential/UID, response
body, or account payload. Create the marker durably **before** the transport may
dispatch the mutation; if writing it fails, abort before dispatch. Clear it only
after valid contract-specific reconciliation/acknowledgement or the existing
durable logout/account-switch transaction. Treat a marker written just before
a process crash as possibly dispatched even when it was not; do not add a
client-side “probably not sent” bypass. The marker and JWT must share a
session-record identity/transaction boundary so an old account's marker cannot
attach to a new JWT. No global singleton or navigation-owned marker.

This is a proposed exception, **not approved persistence**. The owner must also
choose a migration for JWTs restored from builds that never wrote markers:
absence of a marker cannot prove that an earlier write was clean. Recommended
fail-closed migration is to disable mutations for those legacy restored sessions
until explicit logout and fresh login, without discarding the JWT automatically.
The alternative is a documented acceptance exception for pre-marker sessions.
An owner who keeps literal JWT-only persistence should instead approve the
all-restored-session gate above or authorize backend receipt work. Until one
choice and its UX/acceptance cost are recorded, the policy stays **BLOCKED**.

**Exact owner decision requested:** approve or reject this replacement for the
current persistence sentence: “Only the Binblog JWT and a versioned, nonsecret
reconciliation marker bound to that JWT's secure session record may survive app
restart; passwords, provider proofs, grants and raw recovery codes remain
memory-only.” Approval must include the pre-dispatch write barrier, false-positive
lock/logout escape, and legacy-session migration above. If rejected, owner must
choose the all-restored-session gate or commission backend receipt evidence;
fresh GET and fresh grant alone are not an acceptable third outcome.

#### Required transitions if the recommendation is approved

| Event | Required state and behavior |
| --- | --- |
| Normal JWT restore with a bound, known-clean session record | Create a new local generation; perform valid methods GET before enabling writes. Do not infer principal from HTTP 200. A malformed/error GET keeps actions unavailable; a parsed current-generation `401 authentication_required` follows existing expiry. |
| Restore with pending Unlink marker | Lock writes immediately, before screen-open GET. Repeated valid GET with Google present, timeout, 503 or malformed projection keeps marker and lock. Only fully valid current-session projection with Google absent clears it; never replay DELETE/grant. Persistent contradiction offers refresh/support or explicit logout, not a bypass. |
| Restore with rotation receipt-at-risk marker | Raw codes are unavailable and must never be restored. Show lost-code warning; valid methods GET does not claim old codes are usable or recover them. After valid GET and explicit owner acknowledgement, a **new** rotation may start with a new password grant; no automatic retry of the old POST. GET failure/malformed preserves the gate. |
| Process dies between marker write and dispatch, or after dispatch before receipt | On restore treat both as uncertain. False-positive lock is an accepted cost of write-ahead safety. A received rotation response does not clear the marker until the one-time codes have been explicitly acknowledged; app death before acknowledgement becomes lost-receipt warning. |
| Logout/account switch/current-generation expiry | Existing session authority durably ends the old JWT. Clear its marker in the session-record replacement described in the later approved handoff; new account gets a distinct binding and cannot receive an old callback or marker. Failed durable clearing remains a session-store failure, never silent reuse. |
| Late old-generation response, refresh or cancellation | Cannot change the new session's marker, methods, UI or expiry. Cancellation after possible dispatch is not evidence that the backend skipped the write. No automatic mutation or grant replay on startup, refresh, resume or retry. |

**Developer handoff only after owner decision:** design the session-bound record
and pre-dispatch write barrier for Swift and Flutter without changing the JWT's
authentication authority; add separate Unlink and lost-rotation markers, typed
restore errors and visible blocked/retry/support states. Tests must inject
process death/recreation (not just screen recreation) at each write-ahead,
dispatch, receipt, raw-code display and acknowledgement boundary; verify same
JWT restore, legacy-record migration, error/malformed GET, provider-present
repeats, provider-absent resolution, lost-code warning, logout/account switch,
storage failure, late callbacks, one DELETE/POST only, and no secret persistence.
Reviewer must first close the existing in-process finding and then review the
approved restart implementation. Owner smoke starts read-only and must wait for
both reviews, named disposable fixtures and the other existing acceptance gates.

### Durable reconciliation marker — owner approved 2026-10-14

**Verdict: READY FOR MARKER IMPLEMENTATION only.** Owner approved persistence
of non-sensitive operation type, provider/reason and local session binding so
Unlink and rotation uncertainty survives process death. The only persisted
credential remains the Binblog JWT. This approval does **not** cover passwords,
Google/provider credentials, reauthentication grants, raw recovery codes,
requests/responses, or an exception for SDK-managed Google state. The historical
process-restart decision request above is superseded. The existing same-process
lock has not yet been Reviewer-approved; Reviewer must examine it together with
this marker before owner mutation smoke. Full auth-recovery, Google proof/Link,
first-password and deferred recovery-link integration remain blocked as stated
elsewhere in this handoff. The earlier scoped release's instruction to leave
session stores unchanged is superseded **only for this marker slice**.

#### Storage fact and exact record contract

Swift `KeychainSessionStore` currently stores one JSON-encoded `StoredSession`
in the `active-session` generic-password item and serializes writes through
`SessionCoordinator.persistenceTail`. Flutter `SecureSessionStore` stores one
version-1 JSON value at `binblog.khuonvien.vn.session.v1`, with operations
serialized by `SessionCoordinator._tail`. Keep those existing item/key names,
Keychain accessibility, app identities and logout behavior. Do not use a
second marker key: a separate write could orphan a marker or bind it to a new
account. Swift's legacy `UserDefaults` import must not silently create a
known-clean record. Neither `SecItemUpdate`/`SecItemAdd` nor
`FlutterSecureStorage.write` supplies a documented multi-operation transaction
or compare-and-swap in this code. A successful one-item replacement plus a
fresh readback is the dispatch barrier; do **not** describe it as a general
crash-atomic transaction or a guarantee against an unacknowledged storage loss.

New active record in the same secure item/key (JSON names are normative):

```json
{
  "version": 2,
  "state": "active",
  "token": "<existing Binblog JWT>",
  "session_id": "<new random UUIDv4 at each successful login>",
  "marker": null
}
```

`marker` is either explicit `null` (known clean) or exactly one of these
closed-schema objects; no array, arbitrary provider, free-text reason, raw
response, timestamp, account identifier or extra field is permitted:

```json
{"version":1,"operation_id":"<random UUIDv4>","operation":"unlink_google","provider":"google","reason":"await_provider_absence"}
{"version":1,"operation_id":"<random UUIDv4>","operation":"rotate_recovery_codes","reason":"codes_receipt_at_risk"}
```

For a signed-out record, write only `{"version":2,"state":"signedOut"}`;
there is no token, session ID or marker. Validate exact keys and types,
supported versions, canonical random UUIDv4 format, nonblank token and
operation/reason/provider combinations on read **and** before write. The
`session_id` and `operation_id` are opaque local random fences, never derived
from a JWT, Google subject, email or backend principal; they are not storage
keys and must not be logged. A new login always gets a new `session_id`, even
if the JWT string happens to match an earlier one. This is local record binding,
not proof that a methods response belongs to the owner fixture; principal
matching remains NOT VERIFIED until separately checked.

The single marker matches the existing one-mutation gate: do not replace an
unresolved marker with another operation. No durable `dispatched` bit is needed.
The pre-dispatch marker means **may have dispatched** after restore. A second
durable phase would add a crash window between transport start and phase write;
its absence may cause a false-positive lock, never an unsafe unlock. In memory,
the existing synchronous `beginDispatch` gate still distinguishes a proven
pre-dispatch cancellation from a possibly sent request. The only normal
operation that may replace `marker:null` is a conditional prepare for the
current `session_id`; clearing compares both IDs and operation type.

#### Ownership, ordering and crash windows

1. `SessionCoordinator` owns the secure record, record ID, marker and all
   serialized writes. Expose a narrow, typed marker API to account management:
   `prepare(kind, expectedGeneration)` returns an opaque lease containing the
   local record/operation IDs; `clear(lease, resolution)` conditionally clears;
   `currentGate(expectedGeneration)` returns only a nonsecret projection. Do
   not expose the JWT or raw JSON to views or continuity. The authenticated
   graph hydrates its gate from the restored record **before** enabling any
   account mutation, and retains the existing generation/run-ID fencing.
2. After successful password reauthentication and while its grant is still in
   memory, recheck current session, no pending marker, full current methods
   capability and one-operation gate. Serialize a full-record replacement with
   the marker; await success, then read back the same secure item and require
   matching `session_id`, `operation_id` and marker. A failed/ambiguous write,
   mismatch, cancellation or generation change means **no mutation dispatch**
   and, if the session remains active, a blocked/retryable auth-management
   state. Release the grant in memory. Do not
   infer that a failed write left the store clean.
3. Only after the barrier, call the existing mutation client with its
   synchronous `beginDispatch` gate. Recheck generation and lease immediately
   before transport start; adapt the narrow client/authority seam if necessary
   so no await separates that check from start. Do not perform an async store
   write inside the synchronous callback. Keep the fixed HTTPS endpoint,
   no-redirect policy and no automatic request retry. If pre-dispatch
   cancellation is *proven* by the gate, conditionally clear the marker; any
   uncertainty leaves it. The consumed grant is never replayed.
4. Crash before marker write: no mutation may have started. Crash or failure
   during write: dispatch was forbidden; any marker that did land is treated as
   uncertain on restore. Crash after a successful barrier but before dispatch:
   marker produces a safe false-positive lock. Crash after dispatch or receipt
   but before durable resolution: restore the lock/warning. A rotation receipt
   displayed before an unacknowledged crash cannot be reconstructed; never
   show invented codes or say old codes remain valid.
5. Marker writes, clears, logout/switch and authentication writes use the
   **same** coordinator serialization queue. Check local generation and
   `session_id` before and after awaited storage work; inside each serialized
   operation read/compare the current stored record, then replace it. A clear
   also compares `operation_id` and exact marker kind. An old callback cannot
   clear a newer operation or overwrite a newly signed-in account. The current
   store APIs lack an OS-level cross-process CAS; this design assumes the
   existing single app process is the writer. Any new extension/second writer
   requires a separate storage review.

#### Reconciliation, release and UI

- **Unlink:** A parsed `200 unlinked` or `not_linked` is a receipt, not proof of
  provider absence. On a fully decoded current-session `GET /api/auth/methods`,
  Google present keeps the marker and all auth-management writes locked,
  including repeated GETs. Timeout, non-JSON, malformed/incomplete projection,
  other error, cancellation and stale generation also keep it. Google absent
  permits a conditional durable clear; publish Unlink resolution and re-enable
  writes **only after** that clear is verified. If clear fails, keep the lock
  and show refresh/support/logout, not success. Never repeat DELETE. A current
  request with the fully parsed definitive `409 last_authentication_method`
  rejection may clear its own prepared marker after exact
  code classification **and a valid authoritative methods refresh**; if either
  condition fails, retain the marker. Other errors leave the prepared marker
  pending under this handoff; do not infer no-write from an error label alone.
  `not_linked` with Google still present is
  not a no-write escape. A restored marker has no such rejection receipt and
  requires provider absence or session end.
- **Rotation:** A valid `recovery_codes_rotated` receipt supplies raw codes once
  in memory. Keep the marker and lock **all** auth-management writes while codes
  are displayed. Clear
  only after a valid current-generation methods refresh **and** explicit owner
  acknowledgement that codes were saved; persist the clear before unlocking.
  On loss/cancellation/background/process death before this point, erase any
  displayed codes, retain `codes_receipt_at_risk` and show that new codes may
  have invalidated old ones. `codes_enrolled` cannot retrieve codes or prove
  which set is usable. After valid methods GET and explicit acknowledgement
  that the prior receipt is unavailable, clear the marker durably; only then
  may an owner explicitly start a **new** rotation with a fresh password grant.
  No auto rotation, replay or fabricated receipt. A clear failure preserves
  the warning/lock. Other post-dispatch errors remain receipt-at-risk; the
  valid-GET-plus-explicit-acknowledgement path is their safe resolution.
- **Session and UI:** Restore of a known-clean v2 active record creates a new
  local generation and starts read-only until a valid methods GET. Restore of
  either marker immediately locks mutation controls before the methods screen
  appears; hydrate graph-scoped `AccountMethodsContinuity` from the coordinator
  rather than creating an empty clean owner. Leave password, grant, codes,
  dialog and other transient state screen/operation-scoped and clear it on
  background, dispose, logout or switch. Inactive/background never logs out a
  valid Binblog session. Only parsed current-generation `401
  authentication_required` uses the existing session-expiry path; other
  provider/reauth/storage/malformed errors preserve the session. A persistent
  contradiction offers refresh, support and explicit durable logout; no
  bypass button. The OS app-switcher snapshot remains a manual privacy gate.
- **Logout/switch:** Invalidate current token and graph immediately as today;
  serialize a token-free v2 signed-out replacement, or the existing safe
  deletion fallback, before allowing a new login. Verify the old record cannot
  be restored; if storage clearing fails, retain the signed-out error gate and
  forbid new login. Swift's legacy `UserDefaults` migration must not resurrect
  the old JWT if deletion is used. A successful new login writes a distinct v2
  active record with `marker:null`. Old callbacks cannot mutate its marker.
  If a failed logout later restores the old JWT, its marker is restored too;
  process death is not treated as successful logout.

#### Migration and storage failures

Existing Swift `StoredSession.active` Keychain values and legacy `UserDefaults`
import, plus Flutter version-1 active JSON, lack marker history. Recognize them
as **legacy quarantined**; retain the Binblog JWT for existing session/device
use and methods GET, while disabling auth-management writes until explicit
durable logout and fresh
login creates v2. Never rewrite them as v2 `marker:null` during `read()` or
ordinary restore. Existing signed-out records and absent stores remain signed
out. This is a fail-closed availability cost of the approved marker policy.

For v2 active data with an intact token but unknown marker version/shape,
invalid local binding or interrupted/ambiguous marker update, restore the JWT
with **auth-management writes quarantined** and typed storage guidance; do not default
the marker to `null`, delete it, or auto logout. If the outer record or token
cannot be validated, use the existing retryable restore/storage error and
durable logout option, not an authenticated clean state. A known-clean `null`
marker is trusted only in an otherwise fully valid v2 active record. Do not
log raw secure records or include secrets in diagnostics. Readback mismatch or
write/clear failure leaves writes disabled in process; retry only the safe
read/conditional-clear or explicit logout path, never a mutation. No separate
marker key means there is no cross-account orphan to garbage-collect.

#### Files, implementation order and verification

| Step | Swift | Flutter | Required outcome |
| --- | --- | --- | --- |
| 1. Typed record and codecs | `kvx/Domain/Auth/Session.swift`, `kvx/Data/Auth/KeychainSessionStore.swift` | `lib/domain/auth/session.dart`, `lib/data/auth/secure_session_store.dart` | Strict v2/marker codec; legacy quarantine; same existing secure item/key; failure injection through fake stores. |
| 2. Session-owned journal | `kvx/Domain/UseCases/SessionCoordinator.swift` and narrow Domain authorizing protocol | `lib/application/auth/session_coordinator.dart` and narrow Domain session interface | Serialized prepare/readback/conditional clear/logout ordering; local record and operation fences; no JWT exposure. |
| 3. Mutation orchestration | `kvx/ViewModels/AccountMethodsViewModel.swift`, `kvx/Services/AuthManagementClient.swift` only if dispatch seam needs change | `lib/application/auth/account_authentication_controller.dart`, `lib/data/auth/auth_management_client.dart` only if needed | Await marker barrier before client call; preserve synchronous dispatch gate, exact endpoints/error mapping, secret cleanup and non-replay. |
| 4. Graph/UI hydration | `kvx/Views/SessionRootView.swift`, `kvx/Views/AccountMethodsView.swift` | `lib/main.dart`, `lib/presentation/screens/account_methods_screen.dart` | Recreate gate from restored record before enabling writes; accessible lock/warning/refresh/logout states; no new auth feature. |
| 5. Focused tests | `kvxTests/AccountAuthenticationTests.swift` plus session-store/coordinator tests as appropriate | `test/auth/account_authentication_test.dart` plus session-store/coordinator tests as appropriate | Fake-store fault injection, process recreation and UI gate, then affected Debug builds/analyze. No production requests. |

Regression matrix: (a) clean v2 restore stays read-only until valid methods;
(b) legacy active and invalid/unknown marker quarantine; (c) marker write
failure/mismatch prevents any DELETE/POST; (d) crash before write, during
write, after acknowledged write before dispatch, after dispatch, after receipt
and before clear reconstructs the correct gate; (e) Unlink `not_linked` then
Google-present repeated GET/503/malformed retains lock through process
recreation, and only provider absence clears; exact current-operation
`last_authentication_method` rejection clears only after exact classification
and valid methods refresh; all other errors preserve the pending marker;
(f) rotation lost receipt never
recovers raw codes, valid GET plus explicit acknowledgement unlocks only after
durable clear, and a fresh operation uses a fresh grant; (g) readback/clear
failure keeps lock, with no UI success; (h) successful/failed durable logout,
account switch, same-JWT new login and stale old callback never transfer or
clear markers across records; (i) screen recreation keeps the same-process
lock and clears secrets; (j) parsed `401 authentication_required` alone expires
the current session. Assert request counts: no mutation before prepare, and no
automatic second DELETE/POST after any error/restart. Inspect persisted test
record keys to prove the allowlist and absence of password, grant, provider
credential and raw codes. A local fake cannot prove power-loss behavior of
Keychain or Flutter secure storage; verify the one-key write/readback behavior
on supported debug devices before owner mutation smoke. Keep the previous
Swift `os_log` launch crash unresolved until independently explained.

**Review and smoke gates:** Developer implements only this marker slice and
reports actual checks. Reviewer re-reviews both the existing same-process
continuity finding and this durable implementation, including migration,
crash windows, storage failures and no secret persistence. Owner mutation
smoke remains prohibited until approval; start with read-only methods and
privacy/background checks on disposable fixtures. Android runtime/principal
verification and provider-SDK credential policy remain separate acceptance
gates. Marker readiness is neither main-task READY nor approval of Google
proof/Link/first-password or `z8tvbhvmvv` work.

#### Ready-to-copy Developer prompt — durable marker only

```text
Bạn là Developer Agent trong /Users/vinhnguyen/Documents/kvx.
Chỉ triển khai mục “Durable reconciliation marker — owner approved 2026-10-14”
trong ai/tasks/z8tvbhuj25-account-auth-recovery-architecture.md. Owner đã
duyệt persist metadata không chứa secret; không mở rộng sang Google SDK state.

Preflight: đọc project/workflow/developer instructions, toàn bộ handoff và
verification report; kiểm tra branch feature/mobile-account-auth-recovery,
HEAD ecf548f8a0679e3f6bcd78beb6b5e2dbf770bfb0, status/diff. Giữ mọi
existing changes và hai documents; không reset/stash/switch/merge/rebase.

Implement v2 secure session record tại key/item hiện có trên Swift/Flutter:
random local session_id, strict allowlist marker, legacy quarantine, one
serialized session-owned pre-dispatch write/readback barrier, conditional
clear by generation/session_id/operation_id, fail-closed storage errors.
Hydrate lock/warning before mutation UI; preserve secrets in memory only,
generation/run fencing, logout/switch order, fixed HTTPS clients and exact
backend error classification. No extra marker key or SDK persistence change.
For Unlink resolve only on valid provider absence (or a same-attempt parsed
`409 last_authentication_method` plus valid GET); provider-present/error/malformed/restart
retains lock. For rotation never reconstruct codes; require valid GET and
explicit acknowledgement before durable clear and any fresh operation.
Never auto replay DELETE/POST or consumed grant.

Add focused fake-store/failure-injection/process-recreation tests for every
regression row in the handoff, then run affected Swift/Flutter tests, scoped
analyze/format, Debug builds with existing Google configuration and diff check.
Do not uninstall apps or erase simulator data. Do not call production or run
live mutations/login. Report exact files/checks, storage limitations,
remaining manual gates and Git status. Do not commit/push/PR/merge, edit
ClickUp, self-approve or mark auth-recovery READY. Stop for Reviewer re-review
of both same-process lock and durable marker before owner mutation smoke.
```

### Provider credential persistence decision and safe boundary

The existing Swift adapter calls `GIDSignIn.sharedInstance.signIn` and reads an
ID token; Flutter `google_sign_in` 7.2.0 calls `authenticate()` through
`google_sign_in_ios` 6.3.6 on iOS. Inspection of the pinned GoogleSignIn-iOS 9.0.0
source (`GIDSignIn.m`, `addSaveAuthCallback` and `saveAuthState`) shows successful
interactive sign-in writes the SDK auth state to its Keychain store. The SDK's
`signOut` removes that store. The Flutter iOS plugin delegates sign-in/sign-out
to this SDK and keeps a `usersByIdentifier` map in process after sign-out, with
existing non-expired tokens potentially accessible until process teardown.
Flutter's `attemptLightweightAuthentication` can restore a previous sign-in,
although the KVX adapter does not call it. On Android, pinned
`google_sign_in_android` 7.2.11 requests Google ID credentials through
CredentialManager and its sign-out path calls `clearCredentialStateAsync`;
this source does not establish what provider-managed state persists or that a
specific cleanup call succeeded. These are **source facts about the pinned
SDK/plugins**, not runtime proof of current Keychain/CredentialManager contents.
Owner cold-start Binblog UI smoke does not establish either.

Consequently, a literal invariant that **no provider credential is ever
persisted anywhere** is incompatible with reusing the current iOS Google SDK
sign-in path: the SDK persists auth state during the interactive flow. Calling
`signOut` in `finally` can remove SDK state after an operation, but cannot make
that operation literally memory-only; it also changes the provider's ongoing
state and needs explicit UX/security review. Do not silently redefine the
existing ClickUp acceptance sentence “Only the Binblog JWT is persisted.” The
2026-10-14 owner decision narrows that sentence only for the nonsecret marker
in the same app-owned session record; it does not approve SDK credential
persistence or change the provider-proof blocker.

**Selected for the released slice:** no new Google SDK call and no provider
proof in its Domain/Application/Data path. Password entry, grants and returned
recovery codes are operation-scoped in memory, never placed in `SessionCoordinator`,
secure store, navigation state, logging or analytics. Existing Google login and
best-effort provider cleanup remain unchanged. This makes the independent slice
implementable without claiming the global provider-persistence invariant is met.

**Owner/security decision required before provider sub-scope:** either (A)
explicitly accept the SDK-managed Keychain state as a documented exception to
the *app-owned* memory-only rule, specify whether explicit post-proof `signOut`
is required and how it coexists with logout/account-switch, then test cleanup on
Swift, Flutter iOS and Android; or (B) keep the literal no-persistence rule and
approve a different provider proof mechanism with evidence that it never writes
credentials durably. Existing adapters cannot satisfy (B). Until a decision is
recorded, provider reauth, Link and Google-only first-password/code rotation
remain blocked. Under either option, app-owned ID tokens and grants remain
single-attempt memory values; no provider restore becomes Binblog authority.

### READY FOR SCOPED IMPLEMENTATION — exact Developer release

**Included now:** aligned Swift/Flutter provider-neutral methods model and
authenticated methods UI; code-aware protected auth-management transport;
password reauthentication; password-authorized recovery-code rotation and
mixed-account Google Unlink; authoritative reconciliation, single-operation
gate and generation fencing. Add typed contracts only for operations actually
used in this slice. The original release left app login and session stores
unchanged; the later durable marker handoff above authorizes only its specified
session-record and coordinator changes.

**Excluded now:** Google provider reauthentication adapter, Google Link,
Google-only first-password/rotation/Unlink flows, public password recovery
initiation/completion, mail/deep-link UX and all AASA/assetlinks/entitlement or
manifest changes. Do not add dormant provider flows behind an enabled button.
The excluded provider operations stay in `z8tvbhuj25` behind the decision above;
the excluded public recovery/link integration belongs to `z8tvbhvmvv`.

Layer handoff:

1. **Domain:** add typed `AuthenticationMethods`, provider method,
   purpose/method enums, bounded failures and repository contracts for included
   methods, password reauth, rotation and Unlink. No URL or Google SDK type.
2. **Data:** add a separate `AuthManagementTransport` using the current Binblog
   snapshot and fixed generation. Decode the bounded `{status,code}` envelope
   before expiry. Map `GET /api/auth/methods`,
   `POST /api/auth/reauthentications` with `method:password` and exact purpose,
   `POST /api/auth/recovery_codes`, and
   `DELETE /api/auth/social_identities/google` with its grant. Keep JWT in the
   existing request path, no redirect/header/body secret logging, no automatic
   mutation retry, and no new persistence. Restrict receipt decoding to typed
   allowlisted fields.
3. **Application:** use cases own one in-flight operation, temporary password
   and purpose-bound grant; clear them on response, error, cancellation,
   navigation disposal, logout or generation change. Treat uncertain rotation
   specially because raw codes cannot be refetched. Refresh methods after
   definitive or uncertain Unlink; block writes until reconciliation succeeds.
4. **Presentation:** add one generation-scoped authenticated account-methods
   graph in `SessionRootView` and Flutter `_AuthenticatedApp`; expose methods,
   password reauth, guarded rotation with one-time code acknowledgement, and
   password-backed Unlink confirmation. Hide unavailable Google-only actions
   rather than suggesting a missing provider flow. Do not add a public recovery
   entry or modify Google URL callbacks.

Contract classification for this slice: `200` successes are decoded by operation;
only **parsed, current-generation** JSON `401 authentication_required` calls
existing `unauthorized(generation)`. A `401 invalid_provider_credential`, other
recognized errors, malformed 401, timeout, 5xx or cancellation preserve a valid
Binblog session. `403 reauthentication_failed/required`, `409
last_authentication_method`, `422 unsupported_method/provider`, `429 rate_limited`
and unknown codes become typed operation failures without raw server text.
Discard every old-generation success/error before UI mutation or session expiry.
`can_unlink` is advisory; server response and reconciled methods are authoritative.

Endpoint mapping for this release (the full backend contract matrix remains
below):

| Endpoint | Request and success | Relevant stable failures / handling |
| --- | --- | --- |
| `GET /api/auth/methods` | Binblog Bearer; decode `password.usable`, `providers[].provider/usable/can_unlink`, `recovery.codes_enrolled`. | `401 authentication_required` expires only current generation; malformed/unknown projection fails closed without exposing user payload. |
| `POST /api/auth/reauthentications` | Bearer; `{purpose,method:"password",password}`; decode opaque `reauthentication_token` and `expires_at` into operation memory. | `400 malformed_request`, `403 reauthentication_failed`, `422 unsupported_method/unsupported_provider`, `429 rate_limited`, `503 provider_unavailable`, `500 internal_error`; none expires a valid session. |
| `POST /api/auth/recovery_codes` | Bearer; `{reauthentication_token}` for `rotate_recovery_codes`; `200 recovery_codes_rotated` returns ten raw codes once. | `400 malformed_request`, `403 reauthentication_required`, `500 internal_error`; uncertain response must not auto-retry and `codes_enrolled` cannot recover values. |
| `DELETE /api/auth/social_identities/google` | Bearer; `{reauthentication_token}` for `unlink_identity`; `200 unlinked/not_linked`, then GET methods. | `403 reauthentication_required`, `409 last_authentication_method`, `422 unsupported_provider`, `500 internal_error`; on timeout/5xx do not replay, reconcile. |

Every protected endpoint can also return parsed `401 authentication_required`;
only that case expires the current Binblog generation. Tests must additionally
prove that `401 invalid_provider_credential` is preserved by the shared
specialized transport for the later Link operation, without exposing Link UI now.

Implementation sequence: (1) typed contract fixtures and specialized transport
with generation/error tests; (2) methods read/UI; (3) password reauth and
operation-memory cleanup; (4) password-backed rotation and one-time display;
(5) mixed-account Unlink and reconciliation; (6) focused Swift/Flutter state,
race, cancellation, malformed-body and security tests; (7) Debug/Release builds
and Reviewer. Do not reuse generic `AuthenticatedTransport` for account-auth
401 classification. Keep Swift/Flutter changes aligned at each step. Existing
device/network paths must remain unchanged.

Acceptance for this slice requires focused tests for every error branch and
generation switch; duplicate-submit and uncertain-result gates; one-time raw
code display and cleanup; no secret persistence/logging; signed iOS builds and
Flutter Android build; and owner-authorized disposable password/mixed fixture
smoke for methods, password grants, rotation, mixed-account Unlink and session
preservation. Cover `last_authentication_method` with a local contract fixture
now; real Google-only refusal smoke follows the provider gate. Principal
correlation must be established privately before any fixture-specific result is
called MATCH. Android runtime and the unresolved
Swift `os_log` crash remain explicit gates for the accepted platform/build;
stop and triage if the crash recurs. Do not run real mutations without named
fixture owner, reset plan and bounded authorization. Real Google provider smoke
and deferred link/mail smoke remain required for their later sub-scopes.

> **Ready-to-copy Developer prompt:** You are Developer Agent in
> `/Users/vinhnguyen/Documents/kvx` on
> `feature/mobile-account-auth-recovery` at expected HEAD
> `ecf548f8a0679e3f6bcd78beb6b5e2dbf770bfb0`, base
> `feature/mobile-social-login`. Read project/workflow/developer instructions,
> this handoff and the prerequisite verification report; preflight status and
> preserve both untracked documents. Implement **only** the READY scoped slice
> above on Swift and Flutter: methods, specialized code-aware transport,
> password reauth, password-authorized code rotation, mixed-account Unlink,
> reconciliation and generation-scoped UI. Do not implement Google reauth,
> Link, first-password, public recovery or link/mail routing. Keep JWT in the
> existing session path; grants/passwords/codes are transient, never logged or
> persisted. Test parsed 401 classification, stale generations, cancellation,
> duplicate writes, uncertain results and code cleanup with local fakes. Run
> focused checks and affected Debug builds; do not use production mutations or
> login without owner fixture authorization. Report changed files, checks,
> limitations and Git status. Do not commit/push/PR/merge, update ClickUp or
> self-approve; stop for independent Reviewer.

### Proposed ClickUp amendment — review only, not written

Proposed name: **[Mobile] Cross-platform auth methods and account management
(recovery links deferred)**. Exact replacement description for owner review:

```markdown
Implements the account-management part of approved architecture z8tvbhu72a on
Swift and Flutter in `kvx`. Recovery-link integration is deferred to linked
[z8tvbhvmvv](https://app.clickup.com/t/z8tvbhvmvv); this scope split does not
approve its URL proposal or waive its security/acceptance requirements.

## Current-task scope
- Provider-neutral methods state and account-management UI, with a specialized
  auth-management client that classifies response codes before session expiry.
- Password and Google reauthentication, first-password setup, recovery-code
  enrollment/rotation, Google Link/Unlink and server-state reconciliation.
- Preserve existing Binblog SessionCoordinators/JWT stores, startup restore,
  durable logout/account-switch and generation fencing on Swift/Flutter.
- Keep provider SDK code in Data/platform adapters and aligned product semantics.
- Stage the work: methods/password-backed rotation and Unlink may start under the
  scoped Architect handoff; Google reauth, Link, Google-only first-password and
  code rotation stay blocked until the provider-persistence decision is approved.

## Deferred to z8tvbhvmvv
- Recovery URL/mail-link contract, public recovery initiation/completion via
  links, mobile deep-link routing, cold/warm/duplicate/invalid link handling,
  browser fallback, Swift/Flutter iOS app selection, Apple Team ID/Android
  signing/domain associations, AASA/assetlinks publication and end-to-end
  link/mail recovery smoke. The follow-up must preserve password versus
  social-only authorization semantics and explicit login after completion.

## Dependencies and security decision
- Backend/API account-auth contract deployed; named Google OAuth registrations
  and build configuration retained. Real reauthentication smoke is an acceptance
  gate after implementation, not an implementation prerequisite.
- The pinned iOS Google SDK saves its auth state to Keychain during interactive
  sign-in. Before provider-dependent work, owner/security must decide whether
  SDK-managed persistence is an explicit exception with cleanup/test policy or
  require a non-persisting alternative. No application-owned provider ID token
  or reauthentication grant may be persisted under either decision. Do not claim
  literal provider memory-only until this decision and evidence exist.
- Named disposable fixtures and authorization are required before real account
  mutations; principal match needs backend correlation. Android runtime and
  release signing remain separate acceptance evidence.

## Acceptance criteria
- Swift and Flutter expose aligned methods, password/Google reauthentication,
  first-password, code rotation, Link/Unlink and reconciliation outcomes.
- Only parsed current-generation 401 authentication_required expires Binblog;
  provider credential, validation, network, cancel and stale results preserve a
  valid session. Lost mutation responses are reconciled, never blindly replayed.
- App-owned credentials/grants/codes stay transient; SDK persistence follows the
  approved policy. Only Binblog JWT belongs to application auth persistence.
- Last-method protection, single-operation gate, one-time code display,
  durable logout/account-switch and generation fencing pass focused tests.
- Representative real-provider and mutation smoke on named disposable Swift,
  Flutter iOS and Flutter Android builds passes after implementation/config;
  principal is verified privately, with redacted evidence.
- Completion of this task does not assert recovery-link/mail/Web fallback or
  AASA/assetlinks acceptance; those remain in z8tvbhvmvv.

## Git
Branch `feature/mobile-account-auth-recovery`; PR base
`feature/mobile-social-login` after independent review and authorization.
```

## Readiness reassessment — 2026-10-12

This is the pre-split readiness snapshot. The scope reconciliation above now
releases its link-independent subset and assigns link integration to
`z8tvbhvmvv`; its earlier full-task BLOCKED verdict remains historical.

### Dependency matrix

`CLOSED` applies only to the stated prerequisite; `OPEN` needs an owner action;
`BLOCKED` prevents release of the full implementation handoff; `NOT VERIFIED`
cannot be inferred from a nearby passing check. The exact owner receipts and
their evidence boundary remain in
`ai/tasks/z8tvbhuj25-debug-smoke-prerequisite-verification.md`.

| Dependency | Status | Evidence and boundary | Stage impact / next action |
| --- | --- | --- | --- |
| Backend contract, production checkout/schema/Web process | **CLOSED for development contract** | Reviewed merge `68daae2a7c234f7cc308750413f718a28e9369ac`; owner/operator evidence reports production checkout at that SHA, all three migrations up, and `myapp` active after restart. Running artifact provenance, other units, backup/rollback and wider runtime configuration are not proved by the methods receipts. | Backend operator retains sanitized deploy/service/backup evidence for acceptance. The former route/404 finding stays closed. |
| Shared Google audience and four OAuth registrations | **CLOSED for named builds** | Production Web process has one `GOOGLE_CLIENT_IDS` entry matching the shared Web client ID. Web, Swift iOS, Flutter iOS and Flutter Android debug package/SHA-1 clients are registered. Swift/Flutter iOS effective plist/signing was checked on Debug builds; repo placeholders intentionally remain empty. | OAuth/mobile owners retain build-to-registration mapping. Android release signing is **NOT VERIFIED**. |
| Existing iOS Google login and startup restore | **CLOSED at owner UI-smoke level** | Owner reports interactive login and cold-start signed-in UI in Swift and Flutter iOS. Developer later observed authenticated Devices roots after ordinary Debug install over the same identities; Reviewer approved probe cleanup. | Does not establish SDK-managed storage, account principal or Android behavior. |
| Authenticated iOS methods | **CLOSED for reported Google-only projection; partial for password fixture** | Owner's 2026-10-12 receipts: password Swift `dcca9447-2c75-40fc-a500-0bea77fb2bcc` and `af1db4d0-30f3-4e06-8a30-e71bc06eb85a`, Flutter `de2cafa1-aa79-46b4-b3c4-f3773601e5fa`; Google Flutter 22:50 `1710bb3d-736f-4d3e-9816-62d3c43b9f01`, Swift 22:51 `23ed8065-eafd-450c-bdc0-d2e70180335b` (Asia/Saigon). All reported 200/JSON PASS/success. Google projection: password false, google usable true/can_unlink false, codes false. Password: password true/codes false; provider arrays not supplied. | Current iOS sessions reached the read contract. Fixture owner can supply redacted password provider arrays for acceptance; HTTP 200 does not establish principal. |
| Principal of owner-named fixtures | **NOT VERIFIED** | Methods response has no principal field; no backend request-ID correlation is in the report. | Does **not** block implementation against the stable contract. Before fixture-specific acceptance or mutations, backend operator privately maps request IDs to disposable accounts and records only MATCH/NOT VERIFIED. |
| SDK-managed Google credential persistence | **NOT VERIFIED** | App source centrally stores Binblog JWT and does not explicitly store provider proof; SDK/plugin-managed storage was not inspected or tested. | Does not by itself block domain/API work. Before provider-reauth acceptance, mobile owners document SDK behavior and prove reauth ID token/grant are not put in application persistence, logs or restoration state; distinguish SDK state from app-owned proof lifetime. |
| Android runtime and release signing | **NOT VERIFIED** | Debug OAuth registration names package/signing SHA-1; no Flutter Android login, methods or cold-start smoke. Prior signing report used a debug key for debug/profile/release, not a production release identity. | Mobile/OAuth owners run Android smoke on the named debug build and supply accepted release SHA-1/SHA-256 before release/App Links acceptance. Runtime smoke follows a build. |
| Recovery URL, mail link and Web fallback | **BLOCKED** | Backend currently emits Devise `/users/password/edit` links with `reset_password_token` or `social_recovery_token`; API completion accepts `recovery_token`. Proposed `/account/recovery` and association URLs returned 404 at the last recorded check. No approved replacement/fallback contract. | Product/backend/mobile approve host/path/query, two mail mappings, browser form and ownership before routing implementation. Deployment and delivery are later acceptance gates. |
| Universal/App Link identity and publication | **BLOCKED** | No approved Apple Team ID, AASA publisher, accepted Android release certificate SHA-256 or assetlinks publisher/evidence. Existing apps declare Google callback/launcher paths only. | Platform/domain owners supply signing/association decisions before entitlements, manifest and routing changes. Serving and OS verification follow implementation. |
| Mail runtime, safe fixtures and mutation authorization | **OPEN for acceptance** | Effective sender/transport and delivery of both mail variants are not evidenced; full disposable password-only/Google-only/mixed/conflict fixture inventory, code custody and bounded mutation approval are absent. Backend key/database/cache/JWKS settings beyond Web audience also need a sanitized run sheet. | Backend/test owners supply environment, inbox, cache/topology, fixtures and authorization before real mutations. These do not require the mobile feature to exist before coding. |
| Real provider reauthentication and recovery smoke | **OPEN after implementation** | Provider reauthentication is **NOT IMPLEMENTED**. Existing Google login is a different operation; mobile Link/recovery flows are also absent. | Keep real-provider, expiry/race, Link/Unlink, mail and recovery smoke mandatory for post-implementation acceptance. |
| Swift launch `os_log` crash | **NOT VERIFIED / unresolved** | Earlier launch produced `EXC_BAD_ACCESS` in `os_log`; later launches succeeded without root-cause evidence. | Neither fixed nor attributed to auth. If it recurs on an accepted build, stop that smoke and triage a sanitized symbol/stack before release. |

The `memory-only` invariant applies to the new app-owned provider proof and
purpose-bound grant. It is not a claim that GoogleSignIn-iOS or
`google_sign_in` never manages credentials internally. The provider adapter
must request a fresh, explicit proof, keep it out of app persistence and
diagnostics, clear operation references on completion/cancel/logout, and let
the backend enforce token age and linked identity. Before accepting that flow,
inspect the exact SDK/plugin storage and sign-out behavior on supported builds
and test the documented policy; do not infer it from current app source alone.

### Stage gates and circular-dependency correction

**Before full implementation release:** the backend API contract and named OAuth
configuration suffice for domain, specialized transport and mock-backed design.
The full task remains **BLOCKED** until product/backend/mobile approve the
canonical recovery link and mail/Web fallback behavior, and platform owners
supply association/signing identity decisions below. No partial Developer
release is implied. Real Google reauthentication, Android runtime smoke, mail
delivery and recovery mutations cannot be prerequisites to writing the feature
that performs them.

**After implementation, before acceptance:** run the original test matrix and
real-provider/manual smoke on approved disposable fixtures and accepted builds.
Prove purpose-bound Google reauthentication on every applicable platform, safe
SDK/application credential lifecycle, exact principal for fixture-specific
claims, Android login/methods/startup, Link/Unlink, first password, codes, mail
delivery, Web fallback, Universal/App Links and recovery outcomes. Keep redacted
request IDs, revision/build/signing, status/code and principal before/after;
never record proofs, JWTs, grants or recovery tokens. The old blocker criterion
requiring real reauthentication **before** implementation is superseded by this
stage split; its acceptance requirement remains mandatory.

### Decisions required to unblock implementation

1. **Product + backend + mobile — canonical recovery contract.** Approve one
   HTTPS host and path, recommended
   `https://khuonvien.vn/account/recovery?recovery_token=<opaque-percent-encoded-token>`;
   confirm exactly one `recovery_token` query key, no account identifier in the
   URL, and the same token body key for `PUT /api/auth/password_recovery`.
   Backend must commit to mapping the current password
   `reset_password_token` and social `social_recovery_token` mail sources to
   that common link without asking mobile to classify account type. Name the
   browser fallback owner, including its social recovery-code/username form,
   generic invalid/expired handling, token redaction and duplicate-submit
   behavior. Exit: written, versioned URL/mail/Web contract and backend change
   owner; deployed route and delivered mail are later gates.
2. **Product + mobile — in-app routing scope.** Approve isolated recovery while
   authenticated, explicit login after completion, cold/warm/duplicate link
   behavior, and whether the optional nonsecret `/account/authentication`
   navigation link is in scope. Link/Unlink begins inside the signed-in methods
   screen; no grant or provider proof goes in an external URL. Exit: signed
   routing UX and path allowlist for Swift, Flutter iOS and Flutter Android.
3. **Apple/Android/domain owners — association identity.** Supply Apple Team ID
   for both bundle IDs, accepted Android debug and release signing SHA-256
   fingerprints, host/TLS ownership and named AASA/assetlinks publishers.
   Approve path-scoped files for `/account/recovery` (and the optional path only
   if selected). Exit: sanitized identifier/certificate inventory and named
   publishers; actual HTTPS serving and OS verification follow build.

The concrete route, token mapping, iOS Universal Link and Android App Link plan
in [Proposed recovery/link routing contract](#proposed-recoverylink-routing-contract--approval-required)
remains a proposal until those exits are recorded. Before real mutation smoke,
backend/test owners must confirm `APP_HOST`/HTTPS `APP_PROTOCOL`, sender and
transport, both mail variants to controlled inboxes, shared cache topology,
stable key/database/JWKS operation, safe fixtures and authorization. The earlier
concern about committed database connection material remains with backend
security; this handoff does not reproduce or resolve its value.

**Historical full-task verdict: BLOCKED.** After the three implementation decisions,
Architect must reconcile them with the backend contract, update this handoff
and explicitly authorize Developer work against
`feature/mobile-social-login`. Until then, do not edit app routing or implement
auth-recovery. Reviewer cleanup approval closes only the temporary probe.

## Debug Smoke Probe

**Historical probe handoff.** Owner smoke and Reviewer-approved cleanup are
recorded in the reassessment above; the instructions in this section are not
authorization to restore the temporary probe.

### Separate verdict and evidence boundary — 2026-10-12

**Probe handoff: READY for a temporary, debug-only implementation and manual
authenticated-methods smoke. Main auth-recovery implementation: BLOCKED.** This
is a scoped exception to the main Developer gate above, authorized only to
resolve the authenticated `GET /api/auth/methods` evidence gap. Do not implement
provider reauthentication or any account mutation as part of the probe.

Owner reports that Swift and Flutter iOS Google login and cold-start UI smoke
passed on the named simulator. That does not establish the backend HTTP result,
Binblog principal, or the methods projection. A read-only debugger attempt on
2026-10-12 did not send a methods request: Swift LLDB runtime expressions hung;
Flutter's local VM service returned 403 and `flutter attach` did not connect.
No JWT was exported. Do not continue debugger troubleshooting without a
specific cause and direct fix.

### Contract and placement

The only request is `GET https://khuonvien.vn/api/auth/methods` with `Accept:
application/json` and the **current Binblog** Bearer JWT. The reviewed backend
contract at `68daae2a7c234f7cc308750413f718a28e9369ac` expects HTTP 200,
JSON, `status: "success"`, `password.usable: bool`,
`providers: [{provider, usable: bool, can_unlink: bool}]`, and
`recovery.codes_enrolled: bool`. `code` is normally absent on success. The
documented expired-session response is JSON HTTP 401 with
`code: "authentication_required"`. Treat `can_unlink` as advisory. Reject a
missing/wrong-typed required field as `INVALID_PROJECTION`; never print the
raw body to diagnose it. Do not infer a fixture's password or recovery state
from the Google login result; compare with the owner's fixture history.

Add one temporary control to each authenticated root, not an account-management
screen. Swift's `SessionRootView.AuthenticatedContent` already owns the fixed
generation and `SessionCoordinator`; Flutter's `_AuthenticatedApp` in `main.dart`
has the same pair and the existing `http.Client`. Show a small **Run methods
smoke** button and a transient sanitized result only in the authenticated
graph. The owner must tap it. No startup, restore, screen-open, or retry action
may issue the request. Disable duplicate taps while one request is in flight.

The probe uses the existing `SessionAuthorizing` (Swift) or `SessionAccess`
(Flutter) authority: take a snapshot for the root's expected generation, form
the Bearer header in memory, dispatch under the authority's generation check,
and check `isCurrent` before parsing or showing a result. Do not read the
Keychain/secure store a second time, parse the JWT, or pass the token to a shell,
debugger, clipboard, file, analytics, or log. Use an ephemeral/no-cookie/no-cache
Swift `URLSession` and the root's existing Flutter HTTP client. Bound the
request timeout to the existing 20-second transport convention and accept only
the fixed HTTPS host/path. No debug server, relaxed TLS check, endpoint picker,
or new credential store is permitted.

**Do not call either generic `AuthenticatedTransport` unchanged.** Both expire
the session on *every* current-generation 401 before body classification. The
probe's narrow GET helper must read the bounded `{status, code}` envelope first:
only a current-generation JSON `401 authentication_required` calls
`unauthorized(snapshot.generation)`; a malformed or other 401 reports a safe
error and preserves the session. After logout/account switch, discard the late
response (including a late 401) as `STALE`, without publishing it or expiring
the replacement session. Swift cancels the task when the generation-scoped view
is removed; Flutter checks `mounted` and `isCurrent` after awaits and clears
the transient result on disposal/generation change. Cancellation does not
retry. Network/TLS/timeout/5xx errors preserve the current session.

### Output boundary

The on-screen result and redacted run sheet contain only: platform/build/time,
HTTP status; JSON content-type pass/fail; `status` or recognized stable error
`code` (never arbitrary server strings); a syntactically bounded
`X-Request-Id` if present; the four contract fields above; and a typed
PASS/FAIL/STALE result. For `providers`, allow only the reviewed `google`
identifier; unexpected values become `UNKNOWN_PROVIDER` without echoing them.
Never display or log raw JSON, headers, JWT, Google credential, user payload,
email, provider UID, or stack/error descriptions that could include them.
Request ID is copied only from the one allowlisted header after a strict
ASCII/length check; do not render the header map.

The methods payload has no principal identifier. The probe therefore reports
**Principal match: NOT VERIFIED**. It may become MATCH only if a backend
operator privately correlates that request ID with the owner-named disposable
fixture and records a redacted attestation. HTTP 200 or an authenticated UI
alone never implies MATCH. The probe does not establish Google SDK credential
persistence or provider reauthentication.

### Build gates, file plan, and session preservation

- **Swift:** add `kvx/Debug/AuthMethodsSmokeProbe.swift` containing the narrow
  request, strict projection decoder, and transient result view, and gate its
  entire contents with `#if DEBUG && AUTH_METHODS_PROBE`. Add only a conditional
  insertion in `kvx/Views/SessionRootView.swift` inside
  `AuthenticatedContent`, passing its existing coordinator and generation.
  The `kvx` synchronized Xcode group discovers a new source under `kvx/`.
  Opt in for the simulator build with
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG AUTH_METHODS_PROBE'` on the
  `xcodebuild` command line, alongside the three already approved Google build
  settings and `CODE_SIGN_IDENTITY=-`. Normal Debug without the extra condition
  and Release contain no control/probe.
- **Flutter:** add `kvx_flutter/lib/debug/auth_methods_smoke_probe.dart` with
  the narrow request, decoder, and ephemeral widget. Insert it only in
  `_AuthenticatedAppState.build` in `kvx_flutter/lib/main.dart`, with the
  current coordinator, generation, and existing HTTP client. Guard creation
  with `kDebugMode && const bool.fromEnvironment('AUTH_METHODS_PROBE')`.
  Opt in using `--dart-define=AUTH_METHODS_PROBE=true` on the Flutter debug
  build. `kDebugMode` remains false even if that define is accidentally passed
  to a profile/release build. Keep the existing
  `GOOGLE_SERVER_CLIENT_ID` Dart define and all three Flutter iOS Xcode OAuth
  settings when rebuilding; the probe introduces no OAuth key.
- Reconfirm simulator UDID before use. Build both apps to DerivedData outside
  the repository, sign for simulator as in `BUILD.md`, and `simctl install`
  over the existing app. Keep bundle IDs `com.kvx.kvx` and
  `com.kvx.kvxFlutter`, signing identity/entitlements, and secure-store
  service/key names unchanged. **Do not uninstall, erase, reset, or delete app
  data.** Reopen each app and confirm the existing Binblog session restores
  before tapping; if it does not, stop rather than logging in/minting a new
  token. Rebuilds preserve identity by design, but restoration must be observed.
- Build Release for both apps with probe opt-in absent, then check that no
  probe control or probe implementation symbol/string is present in the built
  app. Also build normal Debug without opt-in and verify the control is absent.
  A release build must not make a methods request from probe code, even if the
  Flutter Dart define is mistakenly true.
- After smoke, remove the two temporary probe files and their two root
  insertions; clear the build flags and reinstall ordinary Debug builds over
  the same bundle IDs. Review the diff so no diagnostic code remains. Do not
  remove account data or session stores during cleanup.

### Verification and Developer prompt

Use focused fake-authority/HTTP tests for strict 200 allowlisting, malformed
JSON/types/content type, `401 authentication_required` exactly-once expiry,
unknown/malformed 401 session preservation, logout/switch during response,
duplicate-tap gate, and absence of raw data in displayed output. Run signed
Swift and Flutter iOS debug builds, plist/bundle/signature checks, opt-out
Debug and Release absence checks, then a single owner-triggered GET on each
restored disposable session. Record only the allowlisted receipt with time,
platform/build, status, request ID if present, projection, and principal
attestation status. Do not run account mutations. Build/tests alone do not
close the authenticated-methods blocker; the real GET receipt is required.

> Developer: Implement **only** the temporary Debug Smoke Probe described in
> this section on `feature/mobile-account-auth-recovery` after rechecking HEAD
> and working tree. Use the existing session authority and fixed generation,
> with owner-tapped GET and strict allowlist output. Keep JWT in the app request
> path; do not add account-management UI or reauthentication. Build/install over
> the existing simulator app identities, verify restored sessions, and stop for
> owner action at the probe button. Report real HTTP evidence separately from
> UI state, principal match as NOT VERIFIED absent backend correlation, and
> remove the probe after the bounded smoke. Do not change the main Architect
> verdict, commit, push, deploy, or update ClickUp.

## Context and branch boundary

- ClickUp: `z8tvbhuj25 — [Mobile] Cross-platform auth methods,
  reauthentication, and account recovery` (`to do`, inspected 2026-10-11).
- Approved parent architecture: `z8tvbhu72a` (`complete`).
- Backend dependency: `z8tvbhuj22` (`complete`) with a real ClickUp dependency
  from the mobile task.
- Repository: `kvx`, Swift and Flutter in one implementation track.
- Current branch: `feature/mobile-account-auth-recovery`.
- `HEAD`: `ecf548f8a0679e3f6bcd78beb6b5e2dbf770bfb0`.
- Base: `origin/feature/mobile-social-login` at the same SHA.
- Ahead/behind and task diff versus base: `0/0`, none.
- Working tree before this document: clean; task branch has no upstream.
- Future PR base: `feature/mobile-social-login`, an owner-approved exception.
- `origin/main` and PIR merge `f26d481e348fb996cf82313cfdbe41f52187d6c7`
  are intentionally absent. Do not merge, rebase, or cherry-pick them into this task.

## Evidence sources

### Mobile repository

- Session contract: `docs/decisions/mobile-auth-session.md`.
- Google contract: `docs/decisions/mobile-google-social-login.md`.
- Swift session model and owner: `kvx/Domain/Auth/Session.swift:3`,
  `kvx/Domain/UseCases/SessionCoordinator.swift:66`.
- Swift protected transport: `kvx/Services/AuthenticatedTransport.swift:3`.
- Swift provider adapter and presentation owner:
  `kvx/Data/Auth/GoogleSignInAdapter.swift:6`,
  `kvx/ViewModels/SessionViewModel.swift:6`.
- Swift URL entry point: `kvx/kvxApp.swift:22`.
- Flutter session model and owner: `kvx_flutter/lib/domain/auth/session.dart:1`,
  `kvx_flutter/lib/application/auth/session_coordinator.dart:4`.
- Flutter protected transport:
  `kvx_flutter/lib/data/auth/authenticated_transport.dart:4`.
- Flutter Google adapter and presentation owner:
  `kvx_flutter/lib/data/auth/google_sign_in_adapter.dart:5`,
  `kvx_flutter/lib/presentation/providers/session_provider.dart:7`.
- Flutter composition root: `kvx_flutter/lib/main.dart:28`.
- Existing tests: `kvxTests/SessionTests.swift`,
  `kvxTests/GoogleSignInTests.swift`, and `kvx_flutter/test/auth/`.

### Backend contract revision

- Binblog PR #113, `feat: add account auth recovery contracts`.
- Implementation commit: `a7805d7b19d1595c47965585efa770a783c60096`.
- Base at review: `feature/backend-social-login` at
  `ab9c0e0c5f5f6a991411d8a87da2d6ce481c75eb`.
- PR merge commit: `68daae2a7c234f7cc308750413f718a28e9369ac`.
- Merged 2026-10-01 into `feature/backend-social-login`.
- Authoritative contract sources at the implementation commit:
  `config/routes.rb`, `swagger/v1/swagger.yaml`,
  `spec/requests/api/account_auth_spec.rb`, and
  `spec/requests/api/social_auth_swagger_spec.rb`.
- Review evidence recorded in ClickUp: focused auth/OpenAPI suite 148 examples,
  zero failures; migrations, route/OpenAPI generation, and Zeitwerk passed.

## Existing implementation findings

### Shared session behavior already correct

Both platforms have exactly one `SessionCoordinator` owning the Binblog JWT,
secure persistence, startup restoration, durable clearing, and generation
fencing. Startup restores an opaque JWT locally. A current-generation protected
request `401` expires the session; stale responses cannot affect a replacement
account. Logout and account switching fence memory before persistence and block
new authentication while provider cleanup is in progress.

This task must not add another session owner, parse the JWT, persist Google
credentials/grants, or make Google restore authoritative.

### Existing protected transport is unsafe for auth-management unchanged

Swift `AuthenticatedTransport` and Flutter `AuthenticatedTransport` invalidate
the session on every current-generation `401` before a caller can classify the
body. The new Link endpoint intentionally uses two different `401` meanings:

- `authentication_required`: Binblog JWT invalid; expire the session.
- `invalid_provider_credential`: Google proof invalid; preserve the valid
  Binblog session.

Therefore account-auth calls must go through a specialized protected transport
that parses `{status, code}` before deciding whether to call the existing
`unauthorized(generation)` operation. Reusing the generic transport unchanged
would violate a mandatory invariant.

### Google adapters are reusable but configuration is not evidenced

This paragraph records the initial source-only review. The 2026-10-12
reassessment records subsequent named-build OAuth/runtime evidence; SDK-managed
credential persistence and Android runtime remain unverified.

Swift pins GoogleSignIn-iOS `9.0.0`; Flutter pins `google_sign_in: 7.2.0`.
Both adapters obtain an ID token only after an explicit interactive action and
do not persist it. Those adapters can implement a new provider-neutral
`ProviderReauthenticationCredentialSource` boundary without moving SDK types
into Domain/Application layers.

All checked-in Swift/Flutter OAuth build values are intentionally empty. The
repository documents four public OAuth client IDs, but contains no evidence that
the Web audience, both iOS clients, Android client/SHA registrations, mail, and
backend environment are jointly configured for this feature.

### Recovery deep-link routing does not exist

Swift forwards every `onOpenURL` directly to Google Sign-In. Flutter declares
only the Android launcher intent filter and the iOS Google reversed URL scheme.
Neither application has a recovery-link parser or coordinator.

Backend `AuthenticationMailer` currently generates
`edit_user_password_url(social_recovery_token: ...)`, using `APP_HOST` with a
default of `khuonvien.vn`. This is a Web Devise route, not an approved iOS
universal link, Android App Link, or mobile custom scheme. Password recovery may
also use a Devise reset token. The mobile route, domains, token parameter mapping,
browser fallback, and platform association files are not finalized.

## Dependency and evidence matrix

**Historical snapshot (2026-10-11).** Use the 2026-10-12 reassessment matrix for
current statuses. `VERIFIED` here meant that the named source or environment
supplied direct evidence at the earlier date; it did not promote a dependent row.

| Dependency | Status | Evidence and revision/environment | Required owner evidence or impact |
|---|---|---|---|
| Backend contract stable in source | **VERIFIED** | PR #113 head `a7805d7b19d1595c47965585efa770a783c60096`; merge commit `68daae2a7c234f7cc308750413f718a28e9369ac`; current remote `feature/backend-social-login` is exactly the merge commit | This is the minimum contract ancestry, not proof of production deployment. |
| Production release revision selected | **PARTIALLY VERIFIED / BLOCKED** | Owner reports production switched to `feature/backend-social-login`; GitHub shows that branch at `68daae2a7c234f7cc308750413f718a28e9369ac`. No server-side `git rev-parse HEAD` or artifact revision evidence was supplied | Treat branch identity as owner evidence, not exact running-SHA proof. Capture the deployed full SHA and previous production SHA. |
| Backend route deployed at `https://khuonvien.vn` | **ROUTE VERIFIED / DEPLOYMENT ACCEPTANCE BLOCKED** | Confirmed again at `2026-10-11T15:28:49Z` (`22:28:49` Asia/Saigon): HTTP `401`, JSON content type, and `{"status":"error","code":"authentication_required"}`; request ID `94e5f87f-7ed5-42fc-9bcf-cee405458f19` | The former route/404 blocker is closed. Still need running-revision, migration/service, authenticated methods, compatibility, mail, and Google evidence; this `401` does not prove them. |
| Database migrations ready | **VERIFIED IN SOURCE / NOT RUN IN PRODUCTION** | Three additive Rails 7 migrations add `user_identities.disabled_at`, `reauthentication_grants`, and `user_recovery_codes` | DBA/operator must record backup, migration status, execution result, and row/table verification. No production migration was run in this Architect session. |
| Runtime auth configuration | **BLOCKED** | Code identifies `GOOGLE_CLIENT_IDS`, optional `DISABLED_SOCIAL_AUTH_PROVIDERS`, `APP_HOST`, `APP_PROTOCOL`, stable `secret_key_base`, Rails cache, database, outbound Google JWKS, and mail delivery as runtime concerns | Owner must provide sanitized effective-config evidence. Backend source does not document a production SMTP transport and contains existing embedded database connection material; do not reproduce it in handoffs. Backend owner must assess/rotate/externalize it before release. |
| Recovery mail delivery | **BLOCKED** | Social recovery calls `deliver_now`; Devise handles password recovery. Production source has no SMTP settings and the Devise sender remains a placeholder unless externally overridden | Need a named mail environment, configured sender/transport, delivery evidence to controlled inboxes, and redacted logs. |
| Recovery/link URLs finalized | **BLOCKED** | Password mail uses `/users/password/edit?reset_password_token=...`; social mail uses the same Web route with `social_recovery_token`; the API completion body expects `recovery_token`. The proposed `/account/recovery`, AASA, and assetlinks URLs all still returned HTML `404` at `2026-10-11T15:28:49Z` | Approve and implement one canonical HTTPS mobile/Web contract, association files, token mapping, and fallback behavior. Current social Web fallback is not evidenced as functional. |
| iOS/Android link ownership | **BLOCKED** | Neither Swift app nor Flutter iOS/Android declares recovery Universal/App Links | Owner must approve host, Apple Team ID/application identifiers, Android signing certificate SHA-256 values, and who publishes association files. |
| Google SDK capability | **VERIFIED** | Swift GoogleSignIn-iOS `9.0.0` and Flutter `google_sign_in 7.2.0` obtain explicit ID tokens and do not persist them | Capability does not prove any deployed OAuth client configuration. |
| Four-client Google environment | **BLOCKED** | All checked-in build values are empty; backend PR recorded real Google as untested | Need the Web, Swift iOS, Flutter iOS, and Flutter Android OAuth registrations plus sanitized effective-build/backend evidence and a real reauthentication receipt. |
| Auth rate-limit topology | **OPEN OWNER VALIDATION** | Feature uses `Rails.cache`; inspected production config does not select a shared cache store | Owner must state production process count/cache store and accept or correct cross-process rate-limit behavior before production acceptance. |
| Safe smoke fixtures | **BLOCKED** | No named password-only, Google-only, mixed-method, conflict, or recovery-code fixtures were provided | Do not mutate production users. Owner must provision disposable accounts/inboxes and record reset instructions. |
| Existing JWT/session foundation | **VERIFIED** | Swift/Flutter session decisions and implementations provide one JWT owner, secure persistence, logout/switch ordering, and generation fencing | Extend around it; no session redesign is authorized. |

## Authoritative API and error contract

All authenticated requests carry the current Binblog Bearer JWT. Only a parsed
`401 authentication_required` is a session-expiry signal. Any other error,
including `401 invalid_provider_credential`, belongs to the account-auth
operation and must leave the Binblog session authenticated.

### Contract matrix

| Operation | Request | Success | Stable failures and session effect | Retry/reconciliation |
|---|---|---|---|---|
| Inspect methods | `GET /api/auth/methods`; Bearer JWT | `200 {status:"success", password:{usable}, providers:[{provider,usable,can_unlink}], recovery:{codes_enrolled}}` | `401 authentication_required` expires current generation | Safe read retry. Response is authoritative; `can_unlink` is advisory and server rechecks mutations. |
| Reauthenticate | `POST /api/auth/reauthentications`; `{purpose, method, password? or credential?}` + Bearer | `200 {status:"success", reauthentication_token, expires_at}` | `400 malformed_request`; `401 authentication_required` expires; `403 reauthentication_failed`; `422 unsupported_method/unsupported_provider`; `429 rate_limited`; `503 provider_unavailable`; `500 internal_error` | Never persist proof/grant. Lost response may leave an orphan grant that expires; do not automatically replay credentials. User may explicitly start a new attempt. |
| Add first password | `PUT /api/auth/password`; `{username,password,password_confirmation,reauthentication_token}` + Bearer | `200 {status:"success",code:"password_added"}` | `400 malformed_request`; `401 authentication_required` expires; `403 reauthentication_required`; `409 password_already_set`; `422 invalid_password/username_unavailable`; `500 internal_error` | No blind replay after uncertain transport. Discard grant and reconcile with methods. If password becomes usable, treat write as applied; otherwise remain blocked/refreshable. Explicit login still uses existing session until it expires/logs out. |
| Rotate/enroll recovery codes | `POST /api/auth/recovery_codes`; `{reauthentication_token}` + Bearer | `200 {status:"success",code:"recovery_codes_rotated",codes:[String]}`; backend currently returns ten raw codes once | `400 malformed_request`; `401 authentication_required` expires; `403 reauthentication_required`; `500 internal_error` | Raw codes are non-refetchable. Lost success must not be replayed automatically. Reconcile `codes_enrolled`; explain that prior codes may have been invalidated. A user-confirmed new rotation requires new reauthentication. |
| Initiate recovery | `POST /api/auth/password_recovery`; `{email}`; no JWT | Always `202 {status:"accepted"}` for known/unknown/password/social cases | Public contract intentionally does not disclose account existence; request safety/rate controls must not change UI wording | Manual retry may repeat email delivery, so rate-limit/debounce locally. Always show the same accepted message. |
| Complete recovery | `PUT /api/auth/password_recovery`; `{recovery_token,recovery_code?,username?,password,password_confirmation}`; no JWT | `200 {status:"success",code:"password_updated"}`; **no JWT** | `422 invalid_or_expired_recovery`; `429 rate_limited` | Do not auto-submit/replay. On success clear all secrets and route to explicit password login. Social-only completion requires email challenge + one unused code + username; password-account reset uses its Devise token. |
| Link provider | `POST /api/auth/social_identities`; `{provider:"google",credential,reauthentication_token}` + Bearer | `200 code linked/already_linked`; principal unchanged | `400 malformed_request`; `401 authentication_required` expires; `401 invalid_provider_credential` preserves session; `403 reauthentication_required`; `409 identity_conflict/provider_already_linked`; `422 unsupported_provider`; `503 provider_unavailable`; `500 internal_error` | Provider proof and grant are single-attempt memory values. On timeout/5xx do not replay; GET methods. Provider present and usable resolves applied/already-linked; otherwise expose uncertain state and explicit refresh. |
| Unlink provider | `DELETE /api/auth/social_identities/google`; body `{reauthentication_token}` + Bearer | `200 code unlinked/not_linked` | `401 authentication_required` expires; `403 reauthentication_required`; `409 last_authentication_method`; `422 unsupported_provider`; `500 internal_error` | No blind replay. GET methods; provider absent resolves applied. `last_authentication_method` is definitive and methods must be refreshed. |

The backend temporarily accepts `current_password` for Link/Unlink compatibility.
New mobile code must use purpose-bound grants and must not introduce the legacy
field into new UI or repository contracts.

### Grant and recovery semantics

- Purposes are exactly `link_identity`, `unlink_identity`, `add_password`, and
  `rotate_recovery_codes`.
- Methods are `password` and `google`.
- A grant is bound to user and exact bearer-token digest, purpose-bound,
  five-minute, and one-time.
- Google reauthentication additionally requires an enabled identity owned by
  the current user and a provider credential issued no more than five minutes
  ago (with the backend's one-minute future leeway).
- Social recovery challenges currently expire after 30 minutes.
- Raw recovery codes are stored digest-only, returned only on rotation, and
  all remaining codes are consumed after successful social-only recovery.
- Clients must not infer grant usability after any mutation attempt. Discard it
  locally and acquire a new one for another attempt.

## Chosen architecture

### Ownership

`SessionCoordinator` remains the sole Binblog session/JWT authority. Add one
generation-scoped account-auth feature coordinator per authenticated application
graph and a separate public recovery coordinator. Neither can install, persist,
or restore a Binblog session.

The authenticated coordinator receives a fixed generation. Every request takes
a session snapshot for that generation, dispatches under the existing authority,
and verifies generation again before returning or mutating presentation state.
Replacing/logging out the session disposes the graph and clears in-memory secrets.

### Protected auth-management transport

Add a narrow `AuthManagementTransport`, separate from the feature transport:

1. Obtain `SessionSnapshot` for the graph generation.
2. Build the request and dispatch with the snapshot JWT.
3. After response, verify the generation is still current.
4. Decode the bounded error envelope before any unauthorized action.
5. For `401 authentication_required`, call the existing
   `unauthorized(snapshot.generation)` once and return session-expired/stale.
6. For `401 invalid_provider_credential`, return the provider error without
   calling `unauthorized`.
7. For malformed `401`, fail closed as an invalid response and preserve the
   session; do not guess that it means session expiry.

This keeps the security-sensitive exception localized and leaves all existing
device transports unchanged.

### Domain model

Provider-neutral models:

- `AuthenticationMethods`: `passwordUsable`, ordered `providers`,
  `recoveryCodesEnrolled`.
- `ProviderMethod`: provider identifier, `usable`, advisory `canUnlink`.
- `ReauthenticationPurpose` and `ReauthenticationMethod` closed enums matching
  the backend values above.
- `ReauthenticationGrant`: opaque token + expiry, internal to the application
  operation and never exposed as general presentation/session state.
- `AccountAuthFailure`: authentication required, reauthentication failed/required,
  provider credential invalid/unavailable/cancelled, unsupported method/provider,
  last method, identity conflict, provider already linked, password already set,
  invalid password, username unavailable, rate limited, rejected, malformed,
  uncertain transport, and stale generation.
- `RecoveryProof`: opaque token plus a backend-approved recovery kind only after
  URL routing is finalized. Domain code must not depend on a URL scheme.

### Repository and use-case contracts

`AccountAuthRepository` exposes the seven operations in the contract matrix.
It uses typed DTOs and returns only domain values. It never exposes HTTP, SDK,
or token persistence.

Application use cases coordinate:

- load methods;
- obtain reauthentication by password or provider proof;
- add first password;
- rotate codes;
- link/unlink provider;
- initiate and complete recovery;
- reconcile server state after every authenticated mutation or uncertain result.

Provider SDK access is isolated behind
`ProviderReauthenticationCredentialSource`. Google implementations may reuse
the current adapters internally, but must perform only an explicit user action;
they must not call provider auto-restore or become app-session authority.

### Presentation state

Authenticated account management:

```text
unloaded -> loading -> ready
ready -> reauthenticating -> mutating -> reconciling -> ready
                                      -> uncertainBlocked -> reconciling
any current-generation authentication_required -> existing session expiry
logout/switch/generation change -> disposed/stale; no late publication
```

Only one mutation/reauthentication flow may be active. Disable all other account
method actions until reconciliation finishes. `uncertainBlocked` allows only
refresh/cancel-navigation/logout; it never allows blind mutation replay.

Public recovery:

```text
idle -> initiating -> accepted
deep-link received -> enteringProof -> submitting
                   -> completedRequiresLogin
                   -> invalidOrExpired / rateLimited
```

Recovery success never authenticates automatically. It clears the recovery
token/code/password fields and presents explicit Binblog password login.

### Reconciliation rules

- Link: provider visible and usable means applied/already linked.
- Unlink: provider absent means applied. A present unusable provider is not
  assumed unlinked; keep state blocked and surface refresh/support guidance.
- Add password: `password.usable == true` means applied/already set.
- Code rotation: `codes_enrolled` confirms only that some codes exist; it cannot
  recover raw codes. A lost response remains a special uncertain outcome.
- Definitive server errors still trigger a methods refresh when they concern
  server-authoritative availability (`last_authentication_method`, already set,
  already linked, conflicts).
- Reconciliation failure keeps mutation controls blocked until an authoritative
  refresh succeeds or the session ends.

## Secret and credential lifecycle

| Secret | Owner | Lifetime | Cleanup |
|---|---|---|---|
| Binblog JWT | Existing `SessionCoordinator` + secure session store | Existing session contract | Existing durable logout/switch/401 behavior only |
| Password entry/current password | View/application operation | Until request construction | Clear on submit, cancellation, navigation disposal, logout/switch, success/failure |
| Google ID token | Google platform adapter/application operation | One explicit provider attempt | Clear immediately after backend request construction/completion; never log/persist |
| Reauthentication token | Account-auth operation | One intended mutation, at most server expiry | Clear after any response, transport error, cancellation, logout/switch, or generation change; never reuse automatically |
| Raw recovery codes | Dedicated one-time display model | Until user explicitly acknowledges saving/leaves screen | Disable screenshots only if product/platform policy later requires it; always redact logs/analytics/crash metadata; clear from memory on exit |
| Recovery deep-link token | Public recovery coordinator | Current completion flow only | Never persist in auth state, logs, analytics, navigation labels, or error text; clear after completion/cancel |
| Recovery code input/new passwords | Recovery form operation | Until submit/result | Clear on submit/result/disposal; never place in route state or diagnostics |

No request/response logger may record Authorization headers, provider
credentials, grants, raw codes, recovery URLs/query strings, or password bodies.
Error objects and analytics use only typed nonsecret categories.

Duplicate links are deduplicated in memory while processing. After process
restart, backend one-time/expiry checks remain authoritative; the app shows the
generic invalid/expired result and never logs the token to diagnose it.

## Platform layer and file plan

The full-scope file plan below is historical. The scoped release above controls
which files/capabilities may be added now; recovery-link ingress, entitlements,
manifest and public completion belong to `z8tvbhvmvv`.

Exact filenames may follow surrounding conventions, but Developer must keep
these responsibilities separate.

### Swift

- `kvx/Domain/Auth/AccountAuthentication.swift`: domain projections, enums,
  failures, repository/provider-source protocols.
- `kvx/Domain/UseCases/AccountAuthenticationUseCases.swift`: orchestration and
  reconciliation policies.
- `kvx/Services/AuthManagementTransport.swift`: generation-fenced transport and
  code-aware `401` classification.
- `kvx/Services/AccountAuthenticationClient.swift`: endpoint DTO mapping.
- `kvx/Data/Auth/GoogleReauthenticationAdapter.swift` or a conformance on the
  existing adapter: SDK-only fresh credential acquisition.
- `kvx/ViewModels/AccountAuthenticationViewModel.swift`: authenticated state
  machine and single-mutation gate.
- `kvx/ViewModels/AccountRecoveryViewModel.swift`: unauthenticated recovery.
- `kvx/Views/AccountAuthentication/`: methods, reauthentication, add-password,
  recovery-code, Link/Unlink confirmation, and one-time code views.
- `kvx/Views/SessionRootView.swift`: inject the account-auth graph for the fixed
  session generation and add account navigation.
- `kvx/kvxApp.swift`: route URLs between Google and a future
  `RecoveryLinkRouter`; do not let recovery links fall through to Google.
- `kvx/Info.plist`/entitlements: **blocked** until URL decision is approved.
- `kvxTests/AccountAuthenticationTests.swift` and focused view-model/routing tests.

### Flutter

- `kvx_flutter/lib/domain/auth/account_authentication.dart`: aligned domain
  projections, enums, failures, and contracts.
- `kvx_flutter/lib/data/auth/auth_management_transport.dart`: code-aware,
  generation-fenced transport.
- `kvx_flutter/lib/data/auth/account_authentication_repository.dart`: DTO/API
  mapping.
- `kvx_flutter/lib/application/auth/account_authentication_use_cases.dart`:
  orchestration/reconciliation.
- `kvx_flutter/lib/data/auth/google_reauthentication_adapter.dart` or an aligned
  interface on the existing adapter; plugin code stays in Data.
- `kvx_flutter/lib/presentation/providers/account_authentication_provider.dart`
  and `account_recovery_provider.dart`: state owners scoped as above.
- `kvx_flutter/lib/presentation/screens/account_authentication/`: aligned product
  flows and one-time code display.
- `kvx_flutter/lib/main.dart`: construct the authenticated feature with the
  current generation and public recovery route source.
- Android manifest, iOS plist/entitlements, and any deep-link dependency:
  **blocked** until URL decision is approved. No new package is approved yet.
- `kvx_flutter/test/auth/account_authentication_test.dart` plus widget/routing tests.

### Documentation

After blockers clear, update `BUILD.md`, both platform setup notes, and one
decision record with the exact public URL/OAuth configuration. Never add client
secrets or real recovery tokens.

## Alternatives and trade-offs

1. **Put account methods into `SessionCoordinator` — rejected.** It would mix
   application-session authority with server account-management UI and enlarge
   the secret/persistence surface.
2. **Use generic protected transport — rejected.** It expires the session before
   distinguishing provider-credential `401` from JWT `401`.
3. **Persist grants/provider tokens to survive navigation — rejected.** Their
   short, one-time semantics make recovery from persistence unsafe and unnecessary.
4. **Automatically retry Link/Unlink/rotation after timeout — rejected.** The
   mutation may have succeeded and grants/proofs may be consumed.
5. **Treat recovery as Web-only — possible product fallback, not selected.** It
   conflicts with this task's mobile deep-link scope unless the owner explicitly
   changes acceptance criteria.
6. **Choose a deep-link package now — deferred.** The URL/domain and routing
   contract determines whether native universal/app link support is enough or a
   package is justified.

## Dependency readiness findings — 2026-10-11

Historical findings below are retained for traceability. The 2026-10-12
reassessment supersedes their readiness statuses where new evidence exists.

### Verified facts

- PR #113 is merged only into `feature/backend-social-login`. Its merge commit
  `68daae2a7c234f7cc308750413f718a28e9369ac` has parents `ab9c0e0...` and
  implementation commit `a7805d7...`; the remote feature branch currently points
  exactly at `68daae2`.
- Backend `main` currently points at
  `16c5947c55c1e5c0b71e952e2fd3cda38125ed57` and diverges from the feature
  branch. The repository release guide says production pulls `main`, but the
  owner reports production has now switched to `feature/backend-social-login`.
  GitHub shows that branch at `68daae2`; the exact checkout/artifact SHA still
  requires server-side evidence because a branch name does not identify a
  running revision permanently.
- PR #113 adds three additive migrations. It adds no JavaScript/CSS asset change.
  Old password and social-session paths remain present, while the new code adds
  account-management routes and strengthens identity handling.
- The app process needs database access, stable Rails key material, outbound
  HTTPS access to Google's JWKS endpoint, backend Google audiences, Rails cache,
  and working mail delivery. Social recovery mail is sent synchronously from the
  Web request path with `deliver_now`; Sidekiq is not the delivery mechanism in
  that code path.
- The production source inspected at the contract revision has no explicit SMTP
  settings, and the checked-in Devise sender is a placeholder unless production
  overrides it elsewhere. The repo also contains existing embedded database
  connection material. Values are intentionally omitted here; the backend owner
  must rotate/externalize or explicitly accept the current deployment mechanism.
- `Authentication::RateLimiter` uses `Rails.cache`. The inspected production
  configuration does not select a shared cache store. This can make rate limits
  process-local when multiple Web processes/hosts are used; deployment topology
  and the effective cache store require owner confirmation.
- The earlier production request at `2026-10-11T15:01:16Z` returned HTML `404`.
  After the reported branch switch, a recheck at `2026-10-11T15:12:21Z` returned
  HTTP `401`, JSON, and exactly
  `{"status":"error","code":"authentication_required"}`. The former route/404
  blocker is closed. The same result was confirmed again at
  `2026-10-11T15:28:49Z` (`22:28:49` Asia/Saigon), request ID
  `94e5f87f-7ed5-42fc-9bcf-cee405458f19`. The response does not expose a running
  revision and reaches bearer rejection before an authenticated methods query can
  prove schema/data.
- At `2026-10-11T15:28:49Z`, the proposed recovery URL,
  `/.well-known/apple-app-site-association`, and
  `/.well-known/assetlinks.json` each returned Rails HTML `404`. Recovery routing
  and platform association remain unimplemented/unapproved. No production
  mutation, migration, restart, authenticated request, or mail send was performed
  in this Architect session.

### Open owner decisions and supplied fields

The owner/backend operator must record all of these in the release evidence:

1. Exact running production SHA and previous production SHA. The owner-approved
   release branch is now `feature/backend-social-login`; record server/artifact
   evidence that the running SHA is `68daae2` or another descendant containing it,
   plus document this exception to the repo guide's `main` deployment procedure.
2. Production SSH target, deploy directory, systemd unit names, database backup
   command/location, maintenance window, rollback SHA, and release operator.
   The repo guide contains examples and placeholders; they are not environment
   proof.
3. Effective, redacted configuration for Google audiences, disabled providers,
   application host/protocol, stable Rails key material, database, mail
   transport/sender, cache store/topology, and outbound HTTPS.
4. Canonical recovery host/path/query contract and whether backend/Web will add
   the proposed common recovery landing route.
5. Apple Team ID and associated-domain ownership for both iOS applications;
   Android release/debug signing certificate ownership for OAuth and App Links.
6. Disposable smoke accounts, controlled inboxes, devices/builds, recovery-code
   custody, and permission to mutate only those fixtures.

## Backend production deployment runbook

This runbook prepares operator actions; it does not authorize or perform them.
Commands below are limited to Rails/Git/systemd operations documented by the
backend repository or direct read-only revision checks. Replace no placeholder
silently. If an owner field is absent, stop the release.

### 1. Freeze the release revision

Record:

- `APPROVED_RELEASE_SHA=<full 40-character SHA>`
- `PREVIOUS_PRODUCTION_SHA=<full 40-character SHA>`
- `DEPLOY_BRANCH=<owner-approved production branch>`
- `DEPLOY_HOST`, `DEPLOY_PATH`, operator, backup identifier, and window

In a trusted backend worktree, verify the approved object and ancestry:

```bash
git fetch origin main feature/backend-social-login
git rev-parse "$APPROVED_RELEASE_SHA"
git merge-base --is-ancestor \
  68daae2a7c234f7cc308750413f718a28e9369ac \
  "$APPROVED_RELEASE_SHA"
git show --no-patch --format='%H %P %s' "$APPROVED_RELEASE_SHA"
```

The ancestry command must exit zero. The currently verified minimum merge SHA is
`68daae2...`; `a7805d7...` alone is the PR head, not the merge/release boundary.
The owner has approved/reported `feature/backend-social-login` as the current
production branch, while the checked-in release guide still says
`git pull origin main`. Record the exact server checkout SHA and the operational
exception; do not infer it from the GitHub branch head or silently revert to the
documented `main` procedure.

### 2. Pre-deployment gates

- Backend review/CI for the approved SHA must pass. At minimum rerun or attach
  evidence for the account-auth, social-auth, Google verifier, route/OpenAPI,
  migration, and eager-load suites recorded by PR #113.
- Record a restorable database backup and verify disk space. The repository
  release guide makes both mandatory but does not define the environment-specific
  backup command.
- Record sanitized effective configuration without secret values:
  - non-empty `GOOGLE_CLIENT_IDS`, including the Web OAuth client used by mobile;
  - intentional `DISABLED_SOCIAL_AUTH_PROVIDERS` value;
  - canonical `APP_HOST` and HTTPS `APP_PROTOCOL`;
  - unchanged/available production Rails key material;
  - working database and outbound HTTPS/DNS/TLS to Google's JWKS host;
  - effective Action Mailer delivery method, sender, and provider credentials;
  - effective Rails cache store and Web process/host count.
- Confirm the standard services documented by the repo for this environment:
  `myapp`, `sidekiq`, `nginx`, and existing `mosquitto`. MQTT configuration did
  not change, so the release guide says not to restart Mosquitto unless it has a
  separate fault/config change.
- From the deploy checkout, inspect migration state before applying changes:

```bash
RAILS_ENV=production bundle exec rails db:migrate:status
```

The three target versions are `20261001090000`, `20261001090100`, and
`20261001090200`.

### 3. Deploy and migrate

The checked-in guide assumes SSH into a Git checkout and uses an unresolved
`/path/to/binblog` placeholder. Owner must supply the real host/path and the
exact safe checkout mechanism for `APPROVED_RELEASE_SHA`; this handoff does not
replace that missing operational detail with a guessed command.

Once the exact SHA is checked out, the repo documents:

```bash
bundle install --deployment --without development test
RAILS_ENV=production bundle exec rails db:migrate
RAILS_ENV=production bundle exec rails db:migrate:status
```

All three target migrations must show `up`. They are additive, but adding the
`user_identities` index can still lock or load a populated MySQL table depending
on its size/server version; the DBA must choose the window and observe it. PR
#113 changes no JavaScript/CSS, so an asset build is not required by this feature
itself. Follow the environment's normal immutable/build pipeline if it always
precompiles assets.

The repository release guide documents this service sequence:

```bash
sudo systemctl stop sidekiq
sudo systemctl restart myapp
sudo systemctl restart sidekiq
sudo systemctl reload nginx
```

Use these names only after the operator confirms they are the actual production
units. Do not restart Mosquitto for this auth-only release.

### 4. Post-deployment evidence

From the deployed checkout and host, capture:

```bash
git rev-parse HEAD
git merge-base --is-ancestor \
  68daae2a7c234f7cc308750413f718a28e9369ac HEAD
RAILS_ENV=production bundle exec rails db:migrate:status
sudo systemctl is-active myapp
sudo systemctl is-active sidekiq
sudo systemctl is-active nginx
```

`HEAD` must equal `APPROVED_RELEASE_SHA`, ancestry must exit zero, all three
migrations must be `up`, and services must be active. Then verify externally:

```bash
curl -i -sS https://khuonvien.vn/api/auth/methods
```

Without a Bearer token this must return HTTP `401`, JSON content type, and exactly
the stable `authentication_required` error envelope, not an HTML page or `404`.
This external route check passed after the owner-reported branch switch and was
confirmed again at `2026-10-11T15:28:49Z`. It closes only that check; it must be
attached to exact running-SHA, schema/service, and authenticated-projection
evidence before deployment readiness is accepted.

Next use a disposable test account through a secret-safe operator procedure to
call the same endpoint with its Binblog JWT. Record only status/schema and a
redacted projection; never paste the JWT. A successful response must demonstrate
the expected password/provider/recovery fields without provider UID or email.

Also capture one controlled password login and one existing social-session
regression check, mail delivery to controlled password/social inboxes, and one
real Google reauthentication only after the OAuth checklist below passes. Route
`401` evidence by itself does not prove migrations, configuration, mail, provider
verification, or the deployed SHA.

### 5. Rollback policy and caveats

- Preselect `PREVIOUS_PRODUCTION_SHA` and use the backend owner's normal
  exact-revision rollback mechanism. The repo guide shows a destructive
  `git reset --hard`, but this handoff does not authorize it or assume the deploy
  checkout has no local state.
- Prefer code rollback while leaving the three additive migrations in place.
  Older code ignores the nullable column and extra tables, avoiding deletion of
  grants, recovery-code digests, and identity disable state.
- Do not use the guide's generic `db:rollback STEP=1` as a complete rollback for
  this release: there are three migrations, and later production migrations may
  change stack order. A database rollback needs a DBA-authored, version-specific
  plan, a verified backup, stopped writes, and explicit acceptance that dropping
  the tables/column destroys security state.
- Changing Rails key material during rollback invalidates JWTs/Devise tokens and
  makes social recovery challenges unverifiable. Keep it stable unless the
  incident response explicitly requires global invalidation.
- After code rollback, restart the confirmed app/worker units, reload Nginx, and
  verify the previous SHA, service health, password login, existing social login,
  and device APIs. Keep the new endpoint disabled/unavailable rather than serving
  a partially migrated implementation.

## Proposed recovery/link routing contract — approval required

This proposal is now owned by follow-up
[`z8tvbhvmvv`](https://app.clickup.com/t/z8tvbhvmvv). It remains unapproved;
no current-task Developer routing work is authorized by this section.

This is a concrete proposal, not an approved contract. It intentionally uses an
HTTPS association URL so the same link has a browser destination when an app is
absent or does not claim it.

### Canonical recovery URL

Recommended candidate:

```text
https://khuonvien.vn/account/recovery?recovery_token=<opaque-percent-encoded-token>
```

Owner may choose a different dedicated auth-link host, but must name exactly one
canonical host with valid TLS and Web ownership. The path is scoped narrowly to
recovery. The single query key is `recovery_token`, matching the public
`PUT /api/auth/password_recovery` body. Do not include email, username, provider,
account type, recovery code, JWT, or analytics identifiers in the URL.

Backend changes are required before this proposal can be approved:

- password-account mail must translate Devise's generated raw
  `reset_password_token` into the canonical `recovery_token` query key;
- social-only mail must translate its current `social_recovery_token` similarly;
- the HTTPS route must serve a functional Web fallback for both token types and
  submit the same API/domain operation, including optional username/recovery-code
  fields for social-only recovery;
- logs, analytics, referrers, reverse proxies, and error pages must redact the
  query value.

The backend completer already accepts both token kinds in the same
`recovery_token` body and determines validity server-side, so the mobile client
must not classify account type from token contents. The current two mail query
keys remain backend implementation inputs only; mobile should not ship support
for them unless owner rejects the canonical route and explicitly approves a
compatibility period.

### Link/Unlink routing

No token-bearing external Link or Unlink URL exists in the verified backend
contract, and none is needed. Link/Unlink begin from the authenticated in-app
account-methods screen, acquire a purpose-bound grant plus an explicit Google
credential, and call the protected APIs. If product wants a Web-to-app shortcut,
the only proposed URL is nonsecret
`https://<approved-host>/account/authentication`; it may navigate to the methods
screen but must not start a provider flow, carry a grant, or switch principal.
Owner must decide whether this optional navigation link is in scope.

### iOS Universal Links

For both `com.kvx.kvx` and `com.kvx.kvxFlutter`:

- add the Associated Domains entitlement `applinks:<approved-host>` to the
  correctly signed targets;
- publish `https://<approved-host>/.well-known/apple-app-site-association` with
  valid `appID` entries `<APPLE_TEAM_ID>.com.kvx.kvx` and
  `<APPLE_TEAM_ID>.com.kvx.kvxFlutter`;
- restrict components/path matching to `/account/recovery` and optionally the
  separately approved nonsecret `/account/authentication` path;
- return the association file without redirect, with the correct JSON content
  type and no authentication.

Swift must route Universal Links before Google callback handling; Google keeps
its existing reversed-client-ID custom scheme. Flutter iOS needs the equivalent
link ingress at the application root. Neither app should claim every URL on the
host.

### Android App Links

For package `com.kvx.kvx_flutter`:

- add an `https` `VIEW`/`BROWSABLE` manifest filter with `android:autoVerify`
  for the approved host and `/account/recovery` path prefix;
- publish `https://<approved-host>/.well-known/assetlinks.json` with package
  `com.kvx.kvx_flutter` and the SHA-256 fingerprints of every signing certificate
  used by an accepted smoke/release build;
- keep launcher and Google provider behavior independent of the recovery filter.

Owner must provide release and approved test certificate fingerprints and decide
whether debug builds are intentionally associated. Do not put private signing
material in the repository.

### Runtime routing behavior

- Validate HTTPS scheme, exact approved host/path, exactly one non-empty decoded
  token no larger than the backend's 2048-byte input bound, and reject fragments
  or unexpected security-sensitive fields. Never log the full URL.
- On cold start, retain one pending proof only in memory until routing is ready;
  present recovery without installing or restoring any provider credential.
- In foreground, a duplicate of the active link cannot create another submit.
  After success it shows the completed/requires-login state; after a definitive
  invalid/expired result it cannot be retried automatically. A different link
  starts a new explicit attempt after clearing the old secret.
- If a Binblog session is authenticated, show an explicit isolated recovery
  flow. Receipt/completion does not log out, replace, or switch the principal.
  After success, choosing to use the recovered account must run the existing
  durable account-switch/logout flow and then require explicit password login.
- Logout/account switch/navigation clears the presented proof and fences late UI
  publication by attempt revision. A late public recovery response may never
  install a JWT or mutate the current session.
- If the app is absent, association fails, or the user chooses the browser, the
  same URL must render the Web fallback. Invalid/expired/consumed tokens show one
  generic result without revealing account existence. Refresh/back/duplicate
  submission must not repeat a successful completion.

### Routing decisions owner must approve

1. Canonical host and path, including whether `khuonvien.vn` is accepted.
2. One `recovery_token` query contract and the backend mail/Web changes required
   to replace the current two query keys.
3. Browser form ownership and behavior for social recovery code + username.
4. Apple Team ID/AASA publisher and Android assetlinks publisher/certificates.
5. Authenticated-session UX and optional nonsecret account-methods navigation URL.
6. Whether any transition period must accept legacy mail links; default is no
   mobile claim for the current `/users/password/edit` links.

## Google OAuth configuration readiness

Exactly four public OAuth clients are required. IDs are public configuration,
but this document records only ownership and sanitized evidence, never actual
values or secrets.

**2026-10-12 update:** all four named registrations and the shared backend Web
audience are evidenced for the recorded builds. Swift/Flutter iOS effective
Debug plist and login smoke are reported. The requirements below distinguish
that existing-login evidence from future reauthentication acceptance; Android
release signing/runtime and SDK-managed storage remain unverified.

### 1. Web OAuth client — backend audience

- Purpose: audience for Google ID tokens verified by Rails.
- Backend: include the client ID in runtime `GOOGLE_CLIENT_IDS`.
- Swift: inject the same value as `GOOGLE_SERVER_CLIENT_ID`, materialized as
  `GIDServerClientID` in `Info.plist`.
- Flutter: supply the same value as plugin `serverClientId`; Android currently
  reads `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`, while Flutter iOS also needs
  `GIDServerClientID` through Xcode build configuration.
- Redirect/scheme: this Web client does not provide the iOS callback scheme.
- Evidence: sanitized effective backend/build values match; a fresh ID token's
  audience is accepted by the deployed verifier; never attach or log the token.

### 2. Swift iOS OAuth client

- Bundle ID: `com.kvx.kvx`.
- Injection: `GOOGLE_IOS_CLIENT_ID` and its reversed form
  `GOOGLE_IOS_REVERSED_CLIENT_ID` as CI/local Xcode build settings outside
  committed source. Current project settings are intentionally empty.
- Redirect/scheme: effective `GIDClientID` plus the exact reversed client-ID URL
  scheme in `CFBundleURLTypes`.
- Evidence: signed build's effective plist contains non-placeholder values,
  callback returns only to the Swift app, explicit sign-in yields an ID token,
  and deployed reauthentication returns a grant for the linked safe account.

### 3. Flutter iOS OAuth client

- Bundle ID: `com.kvx.kvxFlutter`.
- Injection: separate Flutter iOS `GOOGLE_IOS_CLIENT_ID` and reversed ID, plus
  the shared Web server client ID. Checked-in `Debug.xcconfig` and
  `Release.xcconfig` contain empty placeholders; Developer must choose an
  optional gitignored/CI-generated xcconfig or command-line Xcode settings so
  real values are not committed. Editing placeholders with real IDs is not the
  approved secret/config distribution mechanism.
- Redirect/scheme: effective `GIDClientID`, `GIDServerClientID`, and exact reversed
  Flutter iOS client scheme.
- Evidence: signed build plist/config is non-placeholder, callback reaches only
  Flutter iOS, explicit provider action yields a token accepted for deployed
  reauthentication, and no provider token persists.

### 4. Flutter Android OAuth client

- Package: `com.kvx.kvx_flutter`.
- Registration: package plus the required Google OAuth signing certificate
  fingerprint for every accepted build; record at least the SHA-1 expected by
  the Android OAuth client. Maintain a separate SHA-256 inventory for App Links.
- Injection: the Android client registration stays in Google Cloud; the shared
  Web client reaches Dart through
  `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` from local/CI build configuration.
  No Firebase, Google Services Gradle plugin, client secret, or
  `google-services.json` is required.
- Redirect/scheme: platform registration handles Android package/signature
  identity; no recovery custom scheme should be added.
- Evidence: certificate fingerprints from the exact installed APK/AAB signing
  identity match the registered Android client, explicit Google auth succeeds,
  and the fresh token is accepted for deployed reauthentication.

### Shared real-reauthentication evidence

For each platform, use a disposable Binblog account with an enabled linked Google
identity. Record build identifier/signature, platform OAuth registration name,
backend release SHA, request timestamp, HTTP status, stable response code, and
the subsequent methods projection. Success means an explicit user action obtains
a fresh provider proof and `POST /api/auth/reauthentications` returns a
purpose-bound grant. Redact the ID token, grant, JWT, UID, email, and recovery
codes. SDK compilation, fake tests, normal Google sign-in, or token acquisition
without backend acceptance is insufficient.

## Mail and provider smoke readiness

### Fixture and environment checklist

- **Mail:** owner names the environment/provider, verified sender/domain,
  `APP_HOST`, HTTPS protocol, controlled inboxes, delivery/log access, retention,
  and redaction policy. Prove both Devise password mail and social-only recovery
  mail arrive with the approved canonical link.
- **Password-only fixture:** usable username/password, controlled inbox, no
  provider identity. Used for password reauth, Link, password reset, and final
  method checks.
- **Google-only fixture:** enabled Google identity, no password, controlled
  inbox, and disposable recovery codes. Used for Google reauth, first password,
  code rotation, social-only recovery, and last-method refusal.
- **Mixed fixture:** usable password plus enabled Google identity. Used for both
  reauth methods and safe Unlink/relink scenarios.
- **Conflict fixture:** a separate disposable account owns a Google identity.
  Used only to prove generic identity conflict without revealing owner data.
- **Builds/devices:** owner records Swift iOS, Flutter iOS, and Flutter Android
  build IDs, signing identities/fingerprints, OS/device, network, public backend
  URL, and associated-link verification results.

Fixture credentials and codes remain in the approved secret manager/test owner,
not this repository, terminal transcripts, screenshots, or analytics.

### Ordered manual smoke matrix

1. **Baseline compatibility:** password login and existing Google social session
   still issue a Binblog JWT; startup restore remains Binblog-only; existing
   protected device read works.
2. **Methods:** password-only, Google-only, and mixed fixtures return the correct
   usable/can-unlink/codes projection with no provider UID/email leakage.
3. **Password reauthentication:** correct password returns each required purpose
   grant; wrong password, expiry, consumed/wrong-purpose grants, and duplicate
   submit produce stable errors while the Binblog session remains valid.
4. **Google reauthentication:** explicit provider flow on all three platform
   builds yields a fresh proof accepted for the linked fixture. Cancel, invalid
   proof, provider unavailability, and wrong identity do not expire the valid
   Binblog session.
5. **First password:** on a disposable Google-only fixture, add username/password
   after Google reauth, reconcile methods, then prove password login. Never use a
   production user because this permanently changes its auth methods.
6. **Recovery codes:** rotate on a disposable fixture, display exactly once,
   retain one code in the smoke custodian, prove prior codes become invalid, and
   never capture raw values in evidence.
7. **Link:** link an unowned test Google identity to the password-only fixture;
   principal/user ID and Binblog JWT owner remain unchanged. Cancel/failure and
   conflict expose no other-account data. Reconcile rather than replay timeout.
8. **Unlink:** unlink Google from the mixed fixture after the correct purpose
   grant. Attempt Unlink on Google-only and verify
   `last_authentication_method`; no auth method is lost.
9. **Password recovery mail:** initiate for known and unknown addresses and show
   identical accepted UI; controlled password inbox receives the canonical link;
   completion sets a password, returns no JWT, and requires explicit login.
10. **Social-only recovery:** controlled Google-only inbox receives the canonical
    link; completion needs challenge + saved unused code + username; success
    consumes all remaining codes, returns no JWT, and requires explicit login.
11. **Links:** verify cold start and warm/foreground routing on both iOS apps and
    Flutter Android; app-absent/unclaimed links render Web fallback; invalid,
    expired, consumed, duplicated, or refreshed links stay generic and cannot
    resubmit success.
12. **Authenticated link receipt:** receiving recovery while logged in never
    replaces or logs out the current principal. Completing recovery remains
    isolated; choosing the recovered account uses durable account switch and
    explicit password login.
13. **Session expiry classification:** a current-generation
    `401 authentication_required` expires the Binblog session. A
    `401 invalid_provider_credential`, provider cancel/failure, validation error,
    timeout, or 5xx preserves it.
14. **Races:** logout/account switch during reauthentication, Link/Unlink,
    reconciliation, or deep-link completion fences all late results and clears
    transient proofs. Only the existing Binblog JWT may survive restart.

Owner executes these only after deployment/routing/OAuth/mail readiness. Required
evidence is a redacted run sheet containing environment, revision, build/device,
timestamp, expected/actual result, HTTP status/stable code, and session principal
before/after. Screenshots must exclude URL query strings and all secrets.

## Dependency-resolution actions in order

This is the original 2026-10-11 ordering. The reassessment's three
implementation decisions and separate post-implementation acceptance gate
supersede any step here that repeats closed evidence or requires a feature smoke
before the feature exists.

1. Backend operator captures the exact running production SHA after the
   owner-approved switch to `feature/backend-social-login`, proves it contains
   `68daae2`, and supplies deploy path/service/backup/rollback fields plus the
   documented exception to the repo's `main` release procedure.
2. Backend operator validates effective database/key/cache/mail/Google/JWKS
   configuration and resolves the existing committed database-configuration
   exposure through the backend security process.
3. Owner/backend/mobile approve the canonical recovery host/path/query and Web
   fallback, then backend produces both mail variants with that URL.
4. Domain owner publishes/test-validates AASA and assetlinks content; mobile
   owner supplies Apple Team ID and Android signing fingerprints.
5. OAuth owner provisions all four clients and injects sanitized public config
   through approved local/CI channels.
6. Owner provisions disposable accounts/inboxes/devices and grants permission for
   the bounded smoke mutations.
7. Backend operator deploys the approved SHA, applies migrations, captures
   revision/service/schema/route evidence, and performs compatibility/mail/Google
   checks according to the runbook.
8. Architect reconciles all evidence against the exit checklist and changes the
   handoff to READY. Developer then rechecks the mobile branch/base and begins the
   implementation sequence below.

## Implementation sequence after unblock

This is the original full-scope sequence. For the current scoped release, use
the sequence in Scope reconciliation. Public recovery/link steps now belong to
`z8tvbhvmvv`, and provider-dependent steps await the SDK persistence decision.

1. Record approved backend environment revision, URL contract, OAuth setup, and
   a safe test-account matrix. Do not begin configuration from guessed values.
2. Add aligned domain entities, failures, repository contracts, and fixture
   payloads for Swift/Flutter.
3. Implement specialized transports and exhaustive HTTP/body classification,
   especially both `401` branches and stale-generation fencing.
4. Implement account-auth repositories and read-only methods inspection.
5. Add reauthentication sources/use cases with strict memory cleanup.
6. Add first-password and code-rotation flows, including one-time display and
   lost-response behavior.
7. Add Link/Unlink with confirmations, single-operation gates, no replay, and
   authoritative reconciliation.
8. Add public recovery initiation/completion independent of session ownership.
9. Implement the approved recovery link adapter/config on Swift, Flutter iOS,
   and Flutter Android, with Google callback coexistence.
10. Integrate account navigation into generation-scoped authenticated roots and
    recovery entry into signed-out roots.
11. Update setup/decision docs, run focused/full gates, then perform the approved
    real-environment smoke matrix.

Each step must keep Swift/Flutter behavior aligned before proceeding. Platform
differences belong only in SDK/link adapters.

## Test and acceptance matrix

This full matrix remains the safety baseline, allocated between the current
account-management task and `z8tvbhvmvv` by Scope reconciliation. A deferred
test is not waived; do not use missing feature smoke as a coding prerequisite.

### Shared contract tests on both platforms

- Decode methods projection without UID/email/profile leakage.
- Verify every endpoint method/path/body and exact success receipt.
- Map every stable error above, including malformed bodies and unknown codes.
- Prove `401 authentication_required` invalidates once only for the current
  generation.
- Prove `401 invalid_provider_credential` leaves the session/JWT usable.
- Prove timeout, 5xx, provider unavailable, reauth failure, and cancellation do
  not log out a valid session.
- Prove old-generation 200/401/error/reconciliation cannot publish after
  logout, account switch, or same-token replacement.
- Prove duplicate mutation submission is gated in UI and application layers.
- Prove no grant/provider/recovery secret reaches secure storage or logging.

### Operation-state tests

- Password and Google reauthentication success, cancel, invalid, unavailable,
  expired/consumed/wrong-purpose grant outcomes.
- Add-password success, validation errors, already-set, uncertain success, and
  failed reconciliation preserving the write block.
- Recovery-code successful one-time display, acknowledgement cleanup, lost
  response, and explicit re-rotation warning.
- Link success/already-linked/conflict/invalid proof/uncertain response.
- Unlink success/not-linked/last-method/uncertain response.
- Server `can_unlink` changes between display and submit; server result wins.
- Recovery initiation always renders identical accepted UX.
- Recovery completion success requires explicit login and installs no JWT.
- Social-only completion includes recovery code/username; password reset does not
  infer account type from initiation response.
- Duplicate deep link and stale/invalid/rate-limited completion.

### Routing tests after URL approval

- Cold-start and foreground delivery on Swift, Flutter iOS, Flutter Android.
- Google callback still reaches the Google SDK only.
- Recovery URL reaches only recovery routing.
- Unrelated/malformed URLs are ignored without logging query values.
- Link received while authenticated does not replace the current principal.
- Logout/switch during completion disposes authenticated operations and clears secrets.

### Builds and regression gates

- Swift focused tests plus full signed `kvxTests`; compile/run affected UI tests.
- Flutter focused auth/provider/widget tests plus full `flutter test`.
- Touched-scope analyzers and full analyzer with baseline failures classified.
- Signed Swift simulator build, Flutter iOS simulator build, and Flutter Android
  build after link configuration is present.
- Git diff/static checks and secret scan over tracked/untracked files.

### Real-provider/manual smoke prerequisites and scenarios

Prerequisites: backend revision deployed, production-equivalent mail delivery,
approved links/association files, Web audience in backend `GOOGLE_CLIENT_IDS`,
Swift iOS client, Flutter iOS client, Flutter Android client and signing SHA,
safe password-only/social-only/mixed test accounts, and saved recovery code.

Run on Swift, Flutter iOS, and Flutter Android where applicable:

- inspect password-only, social-only, and mixed method projections;
- Google reauthenticate then add first password;
- rotate and securely record recovery codes;
- Link and Unlink without principal switching;
- last-method refusal;
- provider cancellation/unavailability preserves Binblog session;
- initiate email and complete password-account recovery;
- initiate email and complete social-only recovery with saved code;
- app cold-start/foreground recovery links;
- logout/account switch while provider/backend operation is delayed;
- kill/relaunch confirms only Binblog JWT persists and no transient proof returns.

Mock/provider tests are not real-provider smoke. Build success is not runtime link
or mail evidence.

## Blocker exit criteria

**Historical 2026-10-11 checklist.** Current implementation release is governed
by the 2026-10-12 reassessment above. Retain unmet deployment/runtime/mail and
smoke requirements for final acceptance; in particular, item 9 below has moved
to the post-implementation gate and is not an implementation prerequisite.

Developer handoff changes from BLOCKED to READY only when every item below has a
dated, sanitized evidence record:

1. **Exact backend revision:** owner names the deployed 40-character release SHA;
   deployed `git rev-parse HEAD` equals it; ancestry proves it contains
   `68daae2a7c234f7cc308750413f718a28e9369ac`. A branch name or ClickUp/PR state
   is insufficient.
2. **Schema and service health:** all three migration versions are `up`; confirmed
   production app/worker/proxy units are active; no new auth/mailer boot errors
   appear. Backup and previous-release SHA are recorded.
3. **Route contract:** unauthenticated `GET /api/auth/methods` returns JSON HTTP
   `401` with `authentication_required`, never Rails HTML/404. This unauthenticated
   half was reconfirmed on `2026-10-11T15:28:49Z`. The remaining half is a disposable
   authenticated request returning the complete, privacy-safe methods projection.
4. **Compatibility:** controlled password login, existing Google social-session
   exchange, startup JWT use, and one protected API read still work on the same
   deployed revision. No claim is based only on unit tests.
5. **Runtime configuration:** backend owner confirms effective Google audiences,
   provider enablement, stable Rails key material, database, outbound Google JWKS,
   mail sender/transport, canonical host/protocol, Rails cache/topology, and the
   disposition of existing committed database connection material without
   publishing secret values.
6. **Approved routing contract:** owner/backend/mobile sign off the exact HTTPS
   recovery host/path and `recovery_token` mapping (or document an explicit
   alternative), both backend mail variants, Web fallback, invalid/duplicate
   behavior, authenticated-session behavior, and absence/presence of any separate
   nonsecret Link navigation URL.
7. **Association evidence:** AASA contains both iOS application identifiers;
   assetlinks contains `com.kvx.kvx_flutter` with the accepted SHA-256 signing
   certificates; files are reachable over HTTPS without redirect/auth and platform
   verification succeeds on the named builds.
8. **Four OAuth clients:** sanitized inventory proves the Web audience, Swift iOS
   client for `com.kvx.kvx`, Flutter iOS client for `com.kvx.kvxFlutter`, and
   Flutter Android client for `com.kvx.kvx_flutter` with its signing fingerprints.
   Effective app/backend values match and no client secret is in source.
9. **Real Google reauthentication (post-implementation acceptance):** on each
   accepted platform build, an explicit provider action for a disposable linked
   account yields a fresh ID token that
   the deployed `POST /api/auth/reauthentications` accepts for a purpose-bound
   grant. Provider cancellation/failure leaves the Binblog session valid. Tokens
   and grants are redacted.
10. **Mail and recovery readiness:** password and social recovery mail reach
    controlled inboxes with the approved URL; disposable password-only,
    Google-only, mixed, and conflict fixtures plus saved test recovery codes are
    documented and resettable. No production account is needed.
11. **Smoke authorization:** owner names who may run the bounded first-password,
    rotation, recovery, Link/Unlink, last-method, expiry-classification, link, and
    logout/account-switch race scenarios and where redacted evidence is stored.
12. **Architect release:** Architect reconciles the evidence, updates this verdict
    to READY, and explicitly releases Developer work on
    `feature/mobile-account-auth-recovery` against
    `feature/mobile-social-login` at the then-current approved base.

Until then, do not add guessed routes/configuration, implement a partial flow
presented as complete, or change the existing session foundation.

## Developer handoff

**READY FOR SCOPED IMPLEMENTATION — 2026-10-12 scope split.** The exact
included/excluded work, stage gates, secret lifecycle, tests and ready-to-copy
Developer prompt are in Scope reconciliation. It releases no Google-dependent
operation, first-password, public recovery or link integration. Those remain
blocked/deferred as assigned there. Real provider and recovery smoke remain
mandatory after the respective implementation, before acceptance.

Developer must first read `ai/agents/developer.md`, this handoff and the
verification report, recheck branch/base/working tree, and preserve both
untracked documents. No commit, push, PR, merge, ClickUp transition or real
account mutation is authorized by this architecture handoff.
