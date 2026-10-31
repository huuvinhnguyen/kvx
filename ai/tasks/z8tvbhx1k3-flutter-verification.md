# Restore Flutter verification baseline

Task: https://app.clickup.com/t/z8tvbhx1k3
Branch: fix/z8tvbhx1k3-flutter-verification; base origin/main0908e7a.
Previous Switch phase1 work is reconciled/preserved as33intentional files in the
original worktree and an owner-authorized ClickUp patch/report, not stashed,
discarded or falsely committed. This task uses an independent clean worktree.

## Scope and approach

Restore existing demo consumer imports and obsolete named parameters to current
widget contracts; initially exclude shared widgets, live API behavior and reminder
execution. The bounded shared-header scope adjustment below follows actual simulator evidence. The stale demo parameters become visible only after imports resolve.
Demo actions remain local-only and never send device commands. Remove existing
unused imports/variable warning and equivalent deprecated Flutter call sites so
full analyze remains strict; do not silence diagnostics in CI.

CI: compatible pinned Flutter/Dart, actual flutter test step, retain web and
macOS simulator build, remove dead matrix.os step, read-only token, locked pub
resolution and dependency-file diff check. Native Swift XCTest/UI and mobile
manual acceptance remain separate Switch gates; Flutter iOS build is not those.
No pubspec/package version changes, no production credentials/commands/deploy.

## Verification plan

Inspect official Flutter3.41.9 source/tag and bundled Dart SDK version. Standalone
offline Dart analyzer is available as a safe independent check; prior Flutter SDK
initialization metadata request was rejected, so do not retry or bypass it.
Run real Flutter commands only in an authorized suitable toolchain environment.
Add a demo widget regression for rendering/current callback wiring (fake/local).
Read-only independent Reviewer then Final Verifier. Missing real runtime/CI
execution evidence must remain BLOCKED, never claim it from static analysis.
Commit/push only when explicitly authorized and relevant gates reconciled.

## Developer report / evidence

Implemented7paths:
- `.github/workflows/flutter-ci.yml`
- `ai/tasks/z8tvbhx1k3-flutter-verification.md` (this handoff/report)
- `kvx_flutter/lib/domain/entities/schedule.dart`
- `kvx_flutter/lib/presentation/screens/device_detail_screen.dart`
- `kvx_flutter/lib/presentation/screens/relay_widgets_demo_screen.dart`
- `kvx_flutter/test/presentation/screens/relay_widgets_demo_screen_test.dart`
- `kvx_flutter/test/presentation/widgets/relay_toggle_switch_test.dart`

Demo now uses Device object headers/footers, value/onChanged toggle, device/relay
identity plus onAdd reminder form, areRemindersActive/onToggleAll/onDelete list.
It remains an isolated demo with local state/snackbars and no network repository.
Updated deprecated equivalent call sites and removed unused warning sources;
no lint exclusions or --no-fatal-* flags were added. New widget regression mounts
all current constructors and exercises local toggle; existing toggle test also
asserts rendering does not invoke onChanged.

EXECUTED / PASSED:
- Official Flutter git tag3.41.9 HEAD00b0c91f06209d9e4a41f71b7a512d6eb3b9c694,
  engine42d3d75a56efe1a2e9902f52dc8006099c45d937. Downloaded matching Dart SDK,
  `dart --version` reports3.11.5; no Flutter CLI initialization invoked.
- Exact pubspec.lock hosted package archives downloaded with SHA256 checks.
  Standalone Dart3.11.5 analyzer with official matching Flutter/sky_engine source
  and generated disposable package map: full lib+test exit0, no diagnostics.
  Log `/tmp/kvx-baseline-analysis.log` is intentionally empty (machine format).
- Original main under same SDK/config reproduces12errors,3warnings,5infos,
  log `/tmp/kvx-original-analysis.log`. This confirms baseline repairs, not an
  unrelated toolchain/diagnostic suppression.
- Both baseline patch and original Switch33-file patch applied without conflict
  to disposable detached worktree `/tmp/kvx-integration-check`; combined full
  Flutter lib+test standalone analyzer in copied stage /tmp/kvx-combined-analysis
  exit0, no diagnostics,
  `/tmp/kvx-combined-analysis.log`. Original Switch worktree unchanged.
- CI YAML structure checks confirm read-only token, actual analyze/test/web
  steps, compatible pinned SDK, macOS simulator build, lockfile enforcement and
  always-run dependency diff guard; no undeclared matrix condition.
- Dart formatting and git diff whitespace checks. pubspec.yaml/pubspec.lock,
  shared widget implementations and native Swift sources unchanged.

NOT RUN / BLOCKED:
- Actual `flutter pub get`, `flutter analyze`, `flutter test`/widget execution,
  Web/iOS builds and remote CI. Prior metadata-service probe during Flutter SDK
  initialization was auto-review rejected; no retry/bypass in this task. Offline
  analyzer is a separate check, not equivalent to real Flutter runtime tests.
- Xcode native Swift build/kvxTests/UI and representative simulator/device smoke;
  current environment is Linux without Apple SDK. CI Flutter simulator build
  will not establish native Swift or manual/hardware acceptance.
- New widget test is statically checked, NOT EXECUTED. No test-pass count claimed.

Independent Reviewer flutter_baseline_reviewer inspected all7paths and returned
READY WITH NON-BLOCKING NOTES; no confirmed defect. Initial reviewed manifest
19843f3f0aa7e20149278dcc880dfc842a2e89acef38da71ec42dbaf705aaa42;
this evidence/report section is a subsequent documentation-only addition.
Targeted report re-review passed at7-file manifest
beb072b9dcdc461af69f59d1e1b71e9e2a2aa731ddde71b5b4ed0f54d2595d21:
Reviewer independently reran baseline and combined copied analyzer stages,
both exit0/no diagnostics, and confirmed source bytes match analyzed copies.
This stage-path clarification is documentation-only.
Final Verifier flutter_baseline_final independently confirmed7files, correctbase,
no staged changes, whitespace, source-to-analyzed-copy match, SDKversion and
reran offline full analyzer exit0. Outcome:
**FINAL VERIFICATION BLOCKED — INSUFFICIENT EVIDENCE**.
Actual Flutter dependency resolution/analyze/test/widget, Web/iOS builds and
remote CI remain missing; native Swift/manual mobile acceptance remains separate.
This outcome paragraph is documentation-only after independent verification. CI configuration/source
checks do not prove remote jobs passed or waive required runtime/build evidence.

No commit, push, PR, deploy, data change or device command. Next gate requires
real platform/remote CI execution. If owner explicitly authorizes publication of
an unverified checkpoint, keep it draft and preserve this BLOCKED qualification;
never relabel that exception as READY TO COMMIT or a passed release gate.

## Simulator evidence extension — owner asked the agent to perform the smoke

Baseline commitbc0b67b/PR22 CI run41098878308 already passed strict analyze,
183unit/widgettests, Web and iOS simulator builds. Post-CI Final Verifier kept a
manual demo-flow evidence gate. Owner then requested the agent do this step.

Add a test-only simulator harness to the existing macOS CI job: isolated temporary
app copy, SDK integration_test dependency only in that copy, exact-original-lock
package comparison, actual iPhone Simulator drive,16PNG state captures and JSON
result, artifacts retained7days. App repository pubspec/lock stay unchanged;
no package upgrade or product navigation change. Main test entry launches only
RelayWidgetsDemoScreen, not KvxApp/auth/session/API/MQTT. Covers light/dark,
ON/OFF, add/delete local reminder, group OFF/ON and checks Flutter exceptions.
Templates are outside app Dart analysis until copied into the isolated project,
where actual Flutter analyze and drive are required. Stdlib Python tooling tests
cover source preservation/destination safety and fail-closed dependency checks.

Screenshot driver follows official Flutter3.41.9 packages/integration_test/README.md
and integration_test_driver_extended.dart (iOS screenshots supported). CI artifact
contains only synthetic demo images, selected simulator metadata, driver log and
result/dependency summaries. Image-review completion must be recorded separately
from scripted assertions; do not call automation manual tapping or claim native
Swift/Switch/hardware/production acceptance. No automatic waiver of manual gate.

Current extension checks:4Python testsPASS, bash syntaxPASS, YAML structurePASS,
diff hygienePASS. Actual new simulator scenario/image review NOT RUN pending
reviewed checkpoint publication and CI. Existing commit/push authorization from
owner persists for this bounded verification extension; PR stays Draft, no merge.

Simulator-extension Reviewer inspected8delta paths and returned READY WITH
NON-BLOCKING NOTES. Confirmed P2 (overwriting native screenshot reportData) fixed
by metadata merge preserving screenshots plus16-image assertion. Added explicit
post-scroll frame settling per review recommendation; driver checks exact16names.
Current Python4tests/bash/diff checks passed; actual CI remains pending.

## Simulator launcher timeout follow-up

Published extension8ab17f0 CI41143331896: Linux checks passed (4Python helper
checks, analyze0issues,183Flutter tests, Web build), normal iOS simulator build
passed. Demo smoke FAILED its20minute timeout: simulator boot consumed roughly
8minutes, then the drive-triggered Xcode build did not complete before timeout.
Artifact13021021112 contains metadata/logs only, NO screenshots/UI test result.
Thus there is no simulator interaction or visual acceptance evidence from that run.

Split prepare/build/boot/drive into separately timed CI steps. Build the integration
test target for generic simulator before boot, ad-hoc sign its temporary app,
boot the selected UDID, open Simulator from the active Xcode, then drive the
prebuilt app bundle without another build. Verbose build/drive logs remain in the
always-uploaded artifact. Original app dependencies and product sources unchanged.
Flutter3.41.9 IOSApp.fromPrebuiltApp explicitly supports an uncompressed.app folder.
Local4Python tooling tests, bash syntax and diff checks PASS; revised remote
execution and screenshot review are pending. PR stays Draft; manual gate open.


## Phone-width layout repair following actual UI failure

Sourcef4791ba CI41146461505 proves prepare/build/sign/boot/prebuilt drive work.
Linux checks and normal iOS build PASS; actual simulator test FAILED at initial
frame: RenderFlex overflow8.1pxright. No screenshot/result, so no visual acceptance.
Artifact13020753294 (SHA256550080a400a892dd8ea10118c69e92691331d26b9d01843987d72cc1ba2fae11)
contains logs and metadata, retained7days.

Bounded scope adjustment: repair DeviceInfoHeader's last-connected row so its
text occupies remaining space and wraps beside the refresh button. This shared
widget is currently used only by the demo; the initial no-shared-widget boundary
was our planning constraint, not an owner prohibition. The change is necessary
for the owner-requested representative phone smoke, with no API/domain behavior
or broader redesign. Keep full text, refresh action and strict overflow assertions.
The unbounded row is the suspected source; a passing revised device run must
validate the repair. Change the existing demo regression from1200px desktop width
to390px phone width so this class of mobile overflow cannot be hidden by that test.
Actual revised Flutter/widget/device checks pending CI; no pass inferred locally.


The390px Flutter widget regression on175ec89 (CI41147489337 Linux job124375898461)
then exposed3additional layout errors with exact widget locations:
DeviceInfoHeader version row123px, RelayToggleSwitch label40px, and
RelayReminderList header88px overflow. This regression uses Flutter test fonts;
these values are distinct from the native simulator's8.1px finding. Extend the
same bounded responsive repair to these evidenced rows: wrap version metadata
and constrain text beside switches. Do not shrink fonts, hide controls, widen
the regression viewport, or weaken exception checks. Revised execution pending.
The existing2x toggle also reserves120x96px of layout space around its centered
control, preventing its painted bounds from overlapping the adjacent label.
