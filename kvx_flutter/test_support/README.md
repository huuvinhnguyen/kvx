# Android session restart probe

From `kvx_flutter`, with the dedicated emulator booted:

```sh
bash test_support/android_session_restart_test.sh emulator-5554
```

The runner builds a **test-only** APK using
`android_session_restart_probe.dart`. It replaces the KVX APK on the selected
emulator and writes only synthetic session candidates. It rejects physical
device serials. Do not ship the probe target or run it against a real account.
`ANDROID_SDK_ROOT` or `ANDROID_HOME` can select another SDK installation.
Before any initial clearing, the probe requires clean signed-out state or an
exact match with one of its synthetic candidates. It refuses to replace a real
session or to clear unreadable storage on a reused emulator. If it refuses,
use a separate temporary AVD rather than clearing that emulator's app data.

Each action reads a fixed command from the app-private test control file and
uses the production `SecureSessionStore` and `SessionCoordinator`. The control
file contains no token and is not an auth persistence authority. Authentication
is replaced with a synthetic authenticator; no HTTP request is made.

The probe emits its PASS marker immediately after the acknowledged mutation.
It does not read the store back or wait for a lifecycle/persistence delay before
that marker. The runner polls logcat, force-stops as soon as it observes PASS,
confirms the process stopped, and requires a different PID for the next action.
The sequence verifies acknowledged login restores A, acknowledged logout
restores signed out, and acknowledged switching restores B. The final action
leaves a token-free signed-out record.

After those cases, the runner temporarily replaces the encrypted session
preference XML with malformed XML while the process is stopped. A fresh process
must stay in restoring with a storage error. The original encrypted XML remains
inside the app sandbox, is restored with an exit trap, and signed-out restoration
is checked again. A second corruption case keeps XML well-formed but replaces
the synthetic session ciphertext with invalid Base64, requiring the same
recoverable restoring error. No token or ciphertext is printed/exported. This
is separate storage-corruption evidence, not an injected `commit()` failure.

This exercises the real Android plugin and actual process death/relaunch on the
selected emulator. It is not a Dart mock, hot restart, physical reboot/power-loss
test, or injected disk-write failure test. Native failure-injection tests are
separate evidence. Polling and adb introduce a short unavoidable observation
delay; no immediate read-back is used as durability proof.

`KVX_PROBE_SKIP_BUILD=1` reruns an already-built probe APK for iteration. Use it
only when `build/app/outputs/flutter-apk/app-debug.apk` was built from this probe
entrypoint and contains the current fork.
