# Switch mobile phase1 — Developer handoff

Task: https://app.clickup.com/t/z8tvbhwpmy
Branch: feat/z8tvbhwpmy-switch-web-parity
Base: main0908e7a611d3dfc27725b78757d1144c47a55a1a (fresh clone/pull, clean boundary).
No commit/push/PR/release or production device command performed for this mobile work.

## Delivered behavior

Swift and Flutter route Switch devices to dedicated API-backed screens. Existing
PIR/Buzzer routes and authentication remain intact. Session-bound transport and
Device database ID are used for detail, ON/OFF, duration-only pulse, device refresh,
read-only paginated reminders and default7day server statistics.

Snapshots preserve nullable relay state and unknown online/last_seen. Commands
never optimistically change snapshot, claim physical ACK or show fake countdown.
Seconds/minutes convert once to integerms1000..86400000; invalid/overflow blocked.
GET reload is separate from POST device refresh. Request receipt requires
accepted/publish_returned/acknowledgement:none, request/event IDs. No auto replay.
Unknown outcomes retain a per-device shared guard across screen recreation in the
same authenticated graph; only a successful GET plus explicit physical-check
acknowledgement permits a new deliberate command. In-flight commands cannot be
reconciled away. Session generations and view lifecycle suppress stale responses.

Reminder writes are absent from repositories/UI regardless server capability.
Legacy null dates/durations and unsupported repeats remain visible as invalid.
Load-more preserves ID cursor; display order by parsed start instant then numericID.
Explicit UTC+07 display. Statistics count log_records only, zero days preserved;
no physical runtime inferred. UTC calendar arithmetic avoids phone DST errors.
Existing relay demo models assume nonnullable/physical-runtime fields and are
kept unchanged; new facade-specific types preserve actual backend semantics.

## Verification evidence

- EXECUTED / PASSED: Swift6.2 Linux core slice SwiftPM11tests/0failures. Includes
  real Switch models/repository/usecases/API client, AuthenticatedTransport,
  Session types and VM. Only Linux compatibility imports FoundationNetworking,
  extraction of existing DeviceAPIError type and test resource Bundle.module
  adaptation in disposable test harness; no dependency or source edits in repo.
  Duration, null/missing schemas, scope, log semantics, duplicate command guards,
  unknown/reload/reconcile, navigation re-entry/deactivation, actual URLProtocol
  method/auth/body/bodyless-refresh/timeout502malformed/no-retry covered.
- EXECUTED / PASSED: Dart3.11.5 offline core harness14tests under
  TZ=America/New_York. Actual domain/usecases/DTO/repository/provider source;
  Flutter ChangeNotifier replaced ONLY in disposable harness by minimal listener
  shim and widget test excluded. This is NOT flutter test or widget evidence.
  Includes null/invalid rows, ownership mapping, ID/relay/duration validation,
  method/path/Bearer/body, DST calendar, duplicate/unknown/read recovery,
  selected relay, dispose and re-open continuity. Reviewer independently14PASS.
- EXECUTED / PASSED: standalone offline Dart analyzer on all new Switch code,
  main.dart and new test source: No issues found. Exact pubspec.lock hosted
  packages downloaded and SHA256 verified for static analysis; Flutter SDK3.41.5
  source/sky_engine stubs, standalone Dart3.11.5; not flutter analyze execution.
- EXECUTED / FAILED (existing baseline): full offline Dart lib/test analysis:
  12errors,3warnings,5info. Compared original tracked main sources under same
  analyzer: identical12errors in existing relay_widgets_demo_screen.dart missing
  ../widgets/relay/* imports/undefined widgets. No unrelated repair made.
- EXECUTED / PASSED: Swift core typecheck with swift-version6/default-isolation
  MainActor; SwiftUI wiring/screen/test syntax parse only; Dart format; diff hygiene.
- NOT RUN / BLOCKED: real flutter analyze/test/widget suite. SDK initialization
  auto-review rejected attempted cloud metadata endpoint access (Flutter Azure
  bot detector); rejected operation was not retried or bypassed. Used independent
  offline Dart checks with no metadata access instead. Initial SDK3.41.5 bundled
  Dart3.11.3 is below project^3.11.5; dedicated standalone Dart3.11.5 used above.
- NOT RUN: Xcode app/SwiftUI typecheck, actual iOS XCTest/UI test suite: Linux host
  has no Apple SDK/Xcode. Linux11tests do not establish those gates.
- NOT TESTED: Swift/Flutter simulator/device layout, navigation, accessibility,
  light/dark/text scale, live API/mobile hardware E2E. Backend owner-observed
  hardware smoke is pre-existing evidence, not mobile execution.

Logs (ephemeral validation environment): /tmp/switch-swift-tests.log,
/tmp/switch-dart-tests.log, /tmp/switch-targeted-analyze.log,
/tmp/switch-offline-analyze.log, /tmp/switch-baseline-analyze.log.
Swift harness: /tmp/switch-swift-package, run swift test -j1 -Xswiftc
-disable-batch-mode (initial parallel compile crashed; serial execution passed).
Dart harness: /tmp/switch-dart-check; static stage /tmp/switch-offline-analyze.
Synthetic JSON fixtures copied unchanged from backend PR120 spec/fixtures/switch_api.

## Review and blockers

Independent Reviewer mobile_reviewer inspected all32implementation paths,
closed4findings (session continuity, null reminder, DST/instant sorting, portable
Swift bundled fixture lookup), returned READY WITH NON-BLOCKING NOTES.
Reviewer manifest e6d4d9de0d425d9a4e7769f3ef0ec9e40f03515bcb7795c3cd58361a10b810ac
(no trailing newline). This report is additional documentation path33.
Reconciled by independent mobile_review_reconcile after the final widget-only
scrollUntilVisible test adjustment: current32implementation manifest
63d85ad5f803ebd13ae35ce18a7d6210754ac5c94a91383b1733b9ff279eae39,
READY WITH NON-BLOCKING NOTES. All33files including this report inspected.
The /tmp logs/harnesses described above were transient and are now unavailable
following environment reset. Test results are historical executed evidence from
the preceding tool outputs/reviewer report, not tests re-executed in this session.
Current-session verification: manifest, full source/report review and diff hygiene.
Independent Final Verifier mobile_gate_final returned:
**FINAL VERIFICATION BLOCKED — INSUFFICIENT EVIDENCE**.
Verified branch/base, all33files, no staged changes, Reviewer manifest match,
tracked/untracked whitespace and all10JSON fixtures. Required real Flutter,
Xcode/iOS and manual platform evidence remains missing; baseline analyzer debt
must be reconciled separately. No READY TO COMMIT or publication authority.
This outcome paragraph is a documentation-only addition after that verification.
Code review approval does not waive missing required
platform tests/builds/manual gates. Do not claim READY TO COMMIT from harnesses.

Next verification on a suitable toolchain: flutter analyze (record/fix separately
existing baseline demo debt as authorized), flutter test including switch widget;
Xcode build + kvxTests + relevant UI tests; owner-authorized simulator/device
phase1 parity/manual. Keep ClickUp To Do pending full mobile acceptance.
Commit/push only with explicit authorization under kvx Developer guide.

Backend phase2 z8tvbhwywq owns reminder execution; no scheduler/unlock here.
Rollback via mobile code; no replay, server state rewrite or reminder deletion.

## Complete changed-file set

- `ai/tasks/z8tvbhwpmy-switch-web-parity-architecture.md`
- `kvx/ContentView.swift`
- `kvx/Domain/Repositories/SwitchRepository.swift`
- `kvx/Domain/UseCases/SwitchUseCases.swift`
- `kvx/Models/SwitchDetail.swift`
- `kvx/Services/SwitchAPIClient.swift`
- `kvx/ViewModels/SwitchViewModel.swift`
- `kvx/Views/DeviceDetailView.swift`
- `kvx/Views/DeviceListView.swift`
- `kvx/Views/SessionRootView.swift`
- `kvx/Views/Switch/SwitchDetailView.swift`
- `kvxTests/Fixtures/SwitchAPI/command.json`
- `kvxTests/Fixtures/SwitchAPI/detail.json`
- `kvxTests/Fixtures/SwitchAPI/reminder-write-disabled.json`
- `kvxTests/Fixtures/SwitchAPI/reminders.json`
- `kvxTests/Fixtures/SwitchAPI/statistics.json`
- `kvxTests/SwitchTests.swift`
- `kvx_flutter/lib/application/usecases/switch_use_cases.dart`
- `kvx_flutter/lib/data/models/switch_dto.dart`
- `kvx_flutter/lib/data/repositories/binblog_switch_repository.dart`
- `kvx_flutter/lib/domain/entities/switch_detail.dart`
- `kvx_flutter/lib/domain/repositories/switch_repository.dart`
- `kvx_flutter/lib/main.dart`
- `kvx_flutter/lib/presentation/providers/switch_provider.dart`
- `kvx_flutter/lib/presentation/screens/device_detail_screen.dart`
- `kvx_flutter/lib/presentation/screens/switch_detail_screen.dart`
- `kvx_flutter/test/fixtures/switch_api/command.json`
- `kvx_flutter/test/fixtures/switch_api/detail.json`
- `kvx_flutter/test/fixtures/switch_api/reminder-write-disabled.json`
- `kvx_flutter/test/fixtures/switch_api/reminders.json`
- `kvx_flutter/test/fixtures/switch_api/statistics.json`
- `kvx_flutter/test/switch/switch_test.dart`
- `ai/tasks/z8tvbhwpmy-switch-web-parity-implementation.md` (this report)
