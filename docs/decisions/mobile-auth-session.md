# Mobile Auth Session Foundation — z8tvbhtth5

## Accepted contract

Rails/Binblog JWT is the application session authority. Swift and Flutter each
have one SessionCoordinator, one active token, token-free presentation state,
an installation generation, and a serialized persistence queue.

Startup reads secure storage once. An active nonempty opaque token restores
locally without any validation HTTP call. Absent/signedOut values show explicit
password login. Storage read errors remain recoverable restoring errors. Normal
feature loading may then call the API; network and 5xx failures preserve session.
Only a current-generation 401 ends the session. No refresh/JWT parsing is used.

Password login preserves POST /api/login with username/password and HTTP 200
with token. The provider-neutral authenticate(exchange) boundary accepts a
Binblog session candidate only under an explicit current authentication intent.
Future provider adapters exchange identity evidence with Rails and use this same
boundary; no provider SDK, credentials persistence, or social API assumptions
are implemented here. No backend change is required.

## Ordering and races

- Protected requests use one token/generation snapshot. Dispatch checks and
  starts transport under the same session-authority isolation.
- Feature transports bind to their graph's generation; old graphs cannot borrow
  a replacement account's JWT. New installations use new generations even when
  the token string is unchanged.
- Responses and errors from old generations are discarded before data returns
  to a repository. Root graphs/navigation reset on expiry/logout/switch.
- Concurrent current 401s invalidate once. No failed request is replayed and
  destructive hardware operations never authenticate/retry automatically.
- Logout fences memory and pending installers immediately. Queued persistence
  completes in order; older login writes cannot overtake logout.
- Login publishes only after persistence succeeds and intent is still current.
- Switching durably clears A before starting B. Failed clearing aborts switching.
- Login is blocked during clearing and following an unresolved persistence error.

## One secure store

Persist active(token) or signedOut without a token. There is no random record ID,
approval file, policy store, or direct path_provider/shared_preferences dependency.

Swift uses Security Keychain, WhenUnlockedThisDeviceOnly, synchronization false.
UserDefaults binblog.accessToken is only a one-time migration source when the
secure entry is absent. Secure active/signedOut values always win. Write securely
before removing legacy defaults; never use defaults as request authority.
Because defaults removal is asynchronous, native fallback deletion recreates a
signedOut Keychain sentinel before reporting success. This also prevents legacy
reimport after interrupted migration cleanup.

Flutter uses a repository-owned flutter_secure_storage 10.0.0 fork with
unlocked_this_device on iOS; the Dart/non-Android implementations are unchanged.
Android backup is disabled to avoid restoring encrypted data without its key.
The plugin's Windows implementation brings path_provider transitively into the
lockfile; application auth does not import it or create a policy file. Generated
plugin registrations and CocoaPods setup are part of integrating secure storage.

Logout prefers signedOut replacement, with deletion recovery where supported.
If all durable clearing fails, the current process remains signed out, protected
requests stay blocked, and UI explicitly reports that the old session may
restore after restart. No successful durable logout is claimed. Only the
Binblog token is persisted; passwords and provider credentials are not saved.

Flutter compile-time credentials and request-triggered login are removed.
Password login is an explicit screen action on both platforms. run_iphone16pro.sh
no longer requires or embeds credentials.

## Verification

Automated coverage includes storage success/failure/restart, password payload
and response validation, local/offline restoration, current/concurrent/stale
401s, logout during login/read/write, switching, identical-token replacement,
pre-dispatch generation changes, stale DeviceViewModel/provider graph responses,
Device/PIR/Buzzer Bearer mapping, and Flutter route disposal/reset.

Executed during implementation:

- Native simulator build: EXECUTED / PASSED.
- Signed Swift unit run: EXECUTED / PASSED, 135 tests. The earlier unsigned run
  failed only real Keychain tests; signed rerun resolved them.
- Flutter full suite with fixture BINBLOG_USERNAME/BINBLOG_PASSWORD defines:
  EXECUTED / PASSED, 99 tests. Those defines never trigger login.
- Focused Flutter auth/unit/widget suite: EXECUTED / PASSED, 30 tests.
- Full Flutter analyzer: pre-existing relay demo missing imports prevent a clean
  result; the same errors were confirmed against an unchanged HEAD snapshot.
- Real device Keychain lock/reboot, Android secure storage, live password login,
  hardware mutation behavior, and physical-device manual testing: NOT TESTED.

## Final verification — 2026-09-28

- EXECUTED / PASSED: final signed native simulator unit run, 135/135 (xcresult
  summary; 62 Swift Testing cases plus existing XCTest coverage).
- EXECUTED / PASSED: native UI suite, 6/6. The gate test verifies login and,
  if a persisted session is present, logout; it does not inject a live account.
- COMPILED ONLY: Flutter iOS debug simulator app, including native secure-storage
  plugin and CocoaPods integration. No Flutter native-plugin runtime test claimed.
- EXECUTED / PASSED: full Flutter unit/widget suite, 99/99; focused auth suite,
  30/30; targeted analyzer over changed Dart/auth/test areas, no issues.
- EXECUTED / FAILED: full Flutter analyzer, 20 issues including 12 existing
  errors in relay_widgets_demo_screen.dart. Unchanged HEAD has the same 12 errors
  (21 total issues). These unrelated demo files were left unchanged.
- EXECUTED / PASSED: git diff --check and bash -n run_iphone16pro.sh.
- NOT RUN: Android and desktop builds.
- NOT TESTED: live Rails login, physical-device lock/reboot/backup behavior,
  Flutter plugin storage at runtime on a device, and live hardware operations.

Reproduction commands (repository root unless stated):

```sh
xcodebuild test -project kvx.xcodeproj -scheme kvx -destination 'platform=iOS Simulator,id=F154B71B-C892-4481-8FD4-ECBD4E156106' -derivedDataPath /private/tmp/kvx-auth-derived -parallel-testing-enabled NO -only-testing:kvxTests CODE_SIGN_IDENTITY=-
xcodebuild test -project kvx.xcodeproj -scheme kvx -destination 'platform=iOS Simulator,id=F154B71B-C892-4481-8FD4-ECBD4E156106' -derivedDataPath /private/tmp/kvx-auth-derived -parallel-testing-enabled NO -only-testing:kvxUITests CODE_SIGN_IDENTITY=-
# In kvx_flutter:
flutter test --dart-define=BINBLOG_USERNAME=fixture --dart-define=BINBLOG_PASSWORD=fixture
flutter test test/auth
flutter analyze lib/application/auth lib/data/auth lib/domain/auth lib/main.dart lib/presentation/providers/session_provider.dart lib/presentation/providers/device_provider.dart lib/presentation/screens/binblog_login_screen.dart lib/presentation/screens/device_list_screen.dart lib/presentation/screens/buzzer_detail_screen.dart test/auth test/support test/widget_test.dart test/buzzer/buzzer_test.dart test/pir/pir_test.dart
flutter build ios --simulator --debug
flutter analyze
```

The system CocoaPods/Ruby installation initially failed. The successful Flutter
build used CocoaPods 1.16.2 installed in /private/tmp with the available Ruby 3.1.2;
no system tooling was changed. The earlier unsigned native unit run could not
access Keychain; the final ad-hoc signed run passes real simulator Keychain tests.

## Scope and review handoff — foundation before Android follow-up

Read-only Reviewer follow-up found no remaining blockers after inspecting native
migration sentinel fallback, transport cancellation, provider-neutral candidate
installation, and stale graph/navigation tests. Implementation is ready for
independent review. No commit, push, PR, backend change, or ClickUp state change.

Inspected git diff HEAD, git diff --cached (empty), and every untracked file.
All listed paths are task-related: session foundation, integration, focused
regression tests, secure-storage plugin configuration, and affected setup docs.
Staged files: none. Tracked changes below are unstaged; ?? paths are untracked.

```text

 M BUILD.md
 M ai/PROJECT.md
 M docs/api/device-detail-binblog-contract.md
 M kvx/ContentView.swift
 D kvx/Data/Auth/UserDefaultsAccessTokenProvider.swift
 M kvx/Data/Repositories/RemoteDeviceRepository.swift
 M kvx/Services/BinblogLoginClient.swift
 M kvx/Services/BuzzerAPIClient.swift
 M kvx/Services/DeviceAPIClient.swift
 M kvx/Services/PIRAPIClient.swift
 M kvx/ViewModels/DeviceViewModel.swift
 M kvx/Views/BinblogLoginView.swift
 M kvx/Views/DeviceDetailView.swift
 M kvx/Views/DeviceListView.swift
 M kvx/Views/PIR/PIRDetailView.swift
 M kvx/kvxApp.swift
 M kvxTests/BuzzerTests.swift
 M kvxTests/NativeDeviceLoadingTests.swift
 M kvxUITests/kvxUITests.swift
 M kvx_flutter/README.md
 M kvx_flutter/android/app/src/main/AndroidManifest.xml
 M kvx_flutter/ios/Flutter/Debug.xcconfig
 M kvx_flutter/ios/Flutter/Release.xcconfig
 M kvx_flutter/ios/Runner.xcodeproj/project.pbxproj
 M kvx_flutter/ios/Runner.xcworkspace/contents.xcworkspacedata
 M kvx_flutter/lib/data/datasources/binblog_device_datasource.dart
 M kvx_flutter/lib/main.dart
 M kvx_flutter/lib/presentation/providers/device_provider.dart
 M kvx_flutter/lib/presentation/screens/buzzer_detail_screen.dart
 M kvx_flutter/lib/presentation/screens/device_list_screen.dart
 M kvx_flutter/linux/flutter/generated_plugin_registrant.cc
 M kvx_flutter/linux/flutter/generated_plugins.cmake
 M kvx_flutter/macos/Flutter/Flutter-Debug.xcconfig
 M kvx_flutter/macos/Flutter/Flutter-Release.xcconfig
 M kvx_flutter/macos/Flutter/GeneratedPluginRegistrant.swift
 M kvx_flutter/pubspec.lock
 M kvx_flutter/pubspec.yaml
 M kvx_flutter/test/buzzer/buzzer_test.dart
 M kvx_flutter/test/pir/pir_test.dart
 M kvx_flutter/test/widget_test.dart
 M kvx_flutter/windows/flutter/generated_plugin_registrant.cc
 M kvx_flutter/windows/flutter/generated_plugins.cmake
 M run_iphone16pro.sh
?? ai/tasks/2026-09-28-mobile-auth-session.md
?? docs/decisions/mobile-auth-session.md
?? kvx/Data/Auth/KeychainSessionStore.swift
?? kvx/Domain/Auth/Session.swift
?? kvx/Domain/UseCases/SessionCoordinator.swift
?? kvx/Services/AuthenticatedTransport.swift
?? kvx/ViewModels/SessionViewModel.swift
?? kvx/Views/SessionRootView.swift
?? kvxTests/SessionTests.swift
?? kvx_flutter/ios/Podfile
?? kvx_flutter/ios/Podfile.lock
?? kvx_flutter/lib/application/auth/session_coordinator.dart
?? kvx_flutter/lib/data/auth/authenticated_transport.dart
?? kvx_flutter/lib/data/auth/password_authenticator.dart
?? kvx_flutter/lib/data/auth/secure_session_store.dart
?? kvx_flutter/lib/domain/auth/session.dart
?? kvx_flutter/lib/presentation/providers/session_provider.dart
?? kvx_flutter/lib/presentation/screens/binblog_login_screen.dart
?? kvx_flutter/macos/Podfile
?? kvx_flutter/test/auth/session_test.dart
?? kvx_flutter/test/auth/session_widget_test.dart
?? kvx_flutter/test/support/auth_fixture.dart
```

## Targeted Android follow-up — REV-01 / REV-02

Upstream 10.0.0 Android value/key writes use Editor.apply(), and some metadata
commit() results are ignored. Method completion therefore did not establish the
accepted durable login/logout/account-switch contract. Defaults also enable
destructive resetOnError, which can erase corruption and return absent storage.

The app now uses the repository-owned path dependency in
kvx_flutter/third_party/flutter_secure_storage. Its KVX_PATCH.md records package
archive provenance, exact original file hashes, retained LICENSE, compatibility
and the limited Android patch. No global cache is modified. Existing federated
platform versions and upstream encryption/key names/encodings remain unchanged.

The Android fork uses checked synchronous commit on the existing worker for the
production RSA/OAEP auth profile. Key and metadata prerequisites must acknowledge
persistence before the encrypted record commit can acknowledge login. Logout's
runtime fence is immediate; signedOut replacement or deletion must commit true
before durable success. Total failure remains signed out in-process and warns
that the surviving record may restore after restart. Switching never starts B
before A clearing succeeds. The coordinator and Swift behavior are unchanged.

Production AndroidOptions explicitly sets resetOnError: false. Failed
initialization clears partial caches and cannot call success after error; retry
performs initialization again. Because a false commit can still change memory,
retry synchronously flushes prerequisite metadata/key generations before trust.
Every checked commit updates a fixed private nonsecret marker in that same file,
forcing a disk mutation on Android 7 even after a failed/no-change retry. This
internal marker has no session or restoration semantics and is ignored by the
existing session-key prefix filter; deleteAll retains only that internal marker.
Existing incompatible legacy/cipher profiles fail visibly, preserve their bytes
and require a separately designed explicit migration. Completed upstream 10.0.0
OAEP/GCM data retains its original format and remains readable.

Android itself can classify malformed/unreadable preferences XML as an empty
map. A read-only guard validates existing data/config/wrapped-key files before
acquisition; .bak takes Android's normal recovery precedence. It checks the
preferences XML shape and typed values, raises sanitized errors without content,
and never writes or erases either file. No second persistence authority exists.

Application analysis excludes the vendored package's independent upstream
Dart/dev-test configuration. Its Dart bytes are unchanged; Android changes are
covered by the fork's native tests, and application adapter tests remain in the
normal Flutter suite. Test-only JUnit/Mockito/Robolectric dependencies do not
change production dependencies.

Evidence boundaries: Dart fake-store/channel tests verify ordering, options and
error propagation; native tests inject commit failure and corruption through the
actual Java plugin paths. Neither proves physical persistence. The test-only
Android runner uses synthetic sessions through the real coordinator/adapter,
waits for acknowledgement, force-stops and relaunches with distinct PIDs. Only
executed results from that runner count as restart evidence; physical device
power loss and real credentials/hardware remain outside these checks.

### Targeted verification — executed 2026-09-28

- EXECUTED / PASSED: flutter pub get; path dependency selected at version 10.0.0,
  no federated/runtime dependency version upgrades.
- EXECUTED / PASSED: focused Flutter auth tests, 33/33; full Flutter suite with
  fixture-only defines, 102/102. Dart fake storage/channel tests prove coordinator
  ordering, resetOnError:false and native error forwarding, not disk durability.
- EXECUTED / PASSED: final targeted Dart analyzer on adapter, new tests and probe;
  no issues.
- EXECUTED / FAILED: full Flutter analyzer, same 20 existing issues including 12
  relay demo errors. No new application diagnostics. Initial analysis descended
  into vendored upstream tests without their separate dev dependencies; the
  explicit third_party exclusion resolved those vendor-only diagnostics.
- EXECUTED / PASSED: native :flutter_secure_storage:testDebugUnitTest, 24/24,
  zero skipped/failures/errors (Robolectric API 28). Tests cover actual Java plugin
  failure forwarding, writes/deletes/deleteAll, wrapped keys, markers, retry,
  XML/backup validation, and an injected Android 7 no-change commit model. Mocks
  and the model do not establish physical persistence. The first Gradle attempt
  hit a concurrent build lock; a later test compilation exposed unsupported
  Files.readString/writeString in Android's compile API. The test helpers now
  use readAllBytes/write, and the final run passes.
- EXECUTED / PASSED: final android-x64 debug probe APK build with the finalized native fork.
  First cold Gradle build took about 23 minutes; final incremental build passed.
  An initial runner was edited during that cold build and hit a shell parser
  resume error; the finalized runner is syntax-checked and rerun from the start.

Reproduction from kvx_flutter:

```sh
flutter pub get
flutter test test/auth --no-pub
flutter test --no-pub --dart-define=BINBLOG_USERNAME=fixture --dart-define=BINBLOG_PASSWORD=fixture
flutter analyze lib/data/auth/secure_session_store.dart test/auth/android_secure_session_store_test.dart test_support/android_session_restart_probe.dart --no-pub
# In android, use the installed Android Studio JBR as JAVA_HOME:
./gradlew :flutter_secure_storage:testDebugUnitTest --console=plain
# Boot a dedicated emulator, then from kvx_flutter:
bash test_support/android_session_restart_test.sh emulator-5554
```

- EXECUTED / PASSED: real emulator API 35 x86_64 probe through production
  SecureSessionStore/SessionCoordinator. Acknowledged login PID 10391 was
  force-stopped; fresh PID 10524 restored A. Logout PID 10685 was force-stopped;
  fresh PID 10812 stayed signed out. Switching PID 10970 was force-stopped;
  fresh PID 11046 restored B rather than A. No immediate storage read-back,
  hot restart or artificial persistence delay was used as proof. The runner's
  adb/logcat observation delay is unavoidable.
- EXECUTED / PASSED: fresh-process malformed backing XML error (PID 11205) and
  invalid ciphertext/Base64 error (PID 11291), both remaining recoverable
  restoring errors rather than absent sessions. Original encrypted XML was
  restored inside the app sandbox; PID 11376 confirmed signed out. No live
  credentials, production login or hardware mutations were used. The probe
  also refuses to overwrite an existing nonsynthetic authenticated session.
- EXECUTED / PASSED: shell syntax, git diff --check, original upstream hash/
  LICENSE/non-Android byte checks and full untracked-file scope inspection.
- NOT TESTED: physical-device power loss/reboot, physical-device storage failure,
  API 24 emulator restart and explicit migration of incompatible legacy profiles.
  Native mocks/model coverage does not replace those checks.

Targeted fix is ready for Reviewer re-review. No commit/push/PR/merge/backend or
ClickUp state change occurred. Branch remains feature/mobile-auth-session-foundation;
44 tracked unstaged paths (including the existing deletion), 70 untracked text
files and zero staged files. Before this follow-up: 43 tracked unstaged paths
and 22 untracked files. Added scope is one tracked analyzer configuration and 48
untracked files (44-file vendor fork, three-file probe support, one adapter test);
existing session adapter/dependency/task decision files received targeted updates.
