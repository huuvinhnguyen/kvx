#!/usr/bin/env bash
# Builds a test-only APK and exercises real Android secure storage across
# acknowledged mutations, force-stop, and fresh-PID relaunch. Emulator only.
set -euo pipefail

probe_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
probe_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
probe_adb="$probe_sdk/platform-tools/adb"
probe_serial="${1:-emulator-5554}"
probe_package="com.kvx.kvx_flutter"
probe_activity="$probe_package/.MainActivity"
probe_previous_pid=""
probe_log="$(mktemp "${TMPDIR:-/tmp}/kvx-auth-restart.XXXXXX")"
trap 'rm -f "$probe_log"' EXIT

case "$probe_serial" in
  emulator-*) ;;
  *) echo 'This synthetic-session runner only accepts Android emulator serials.' >&2; exit 2 ;;
esac
[[ -x "$probe_adb" ]] || { echo "adb unavailable: $probe_adb" >&2; exit 2; }
[[ "$($probe_adb -s "$probe_serial" get-state)" == device ]]
[[ "$($probe_adb -s "$probe_serial" shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]
case "$($probe_adb -s "$probe_serial" shell getprop ro.product.cpu.abi | tr -d '\r')" in
  x86_64) probe_target_platform='android-x64' ;;
  arm64-v8a) probe_target_platform='android-arm64' ;;
  armeabi-v7a) probe_target_platform='android-arm' ;;
  *) echo 'Unsupported emulator ABI for the restart probe.' >&2; exit 2 ;;
esac

cd "$probe_root"
if [[ "${KVX_PROBE_SKIP_BUILD:-0}" != 1 ]]; then
  flutter build apk --debug --target-platform "$probe_target_platform" --target test_support/android_session_restart_probe.dart
fi
"$probe_adb" -s "$probe_serial" install -r build/app/outputs/flutter-apk/app-debug.apk

run_probe() {
  local action="$1" current_pid
  "$probe_adb" -s "$probe_serial" shell am force-stop "$probe_package"
  [[ -z "$("$probe_adb" -s "$probe_serial" shell pidof "$probe_package" | tr -d '\r')" ]]
  "$probe_adb" -s "$probe_serial" shell run-as "$probe_package" mkdir -p files
  # Only fixed, nonsecret action names are passed to the app-private control file.
  "$probe_adb" -s "$probe_serial" shell "run-as $probe_package sh -c 'printf %s $action > files/auth-restart-probe-command'"
  "$probe_adb" -s "$probe_serial" logcat -c
  "$probe_adb" -s "$probe_serial" shell am start -W -n "$probe_activity" >/dev/null
  current_pid="$("$probe_adb" -s "$probe_serial" shell pidof "$probe_package" | tr -d '\r')"
  [[ -n "$current_pid" && "$current_pid" != "$probe_previous_pid" ]]

  for ((attempt=0; attempt<150; attempt++)); do
    "$probe_adb" -s "$probe_serial" logcat -d --pid="$current_pid" -v brief >"$probe_log"
    if grep -Fq "KVX_AUTH_RESTART_PROBE FAIL action=$action pid=$current_pid" "$probe_log"; then
      grep -F 'KVX_AUTH_RESTART_PROBE' "$probe_log" >&2
      return 1
    fi
    if grep -Fq "KVX_AUTH_RESTART_PROBE PASS action=$action pid=$current_pid" "$probe_log"; then
      # Kill as soon as the acknowledged action is observed, without readback,
      # hot restart, lifecycle shutdown, or an artificial persistence delay.
      "$probe_adb" -s "$probe_serial" shell am force-stop "$probe_package"
      [[ -z "$("$probe_adb" -s "$probe_serial" shell pidof "$probe_package" | tr -d '\r')" ]]
      echo "PASS action=$action pid=$current_pid previous_pid=${probe_previous_pid:-none} process_stopped=yes"
      probe_previous_pid="$current_pid"
      return 0
    fi
    sleep 0.2
  done
  echo "Timed out waiting for probe action=$action pid=$current_pid" >&2
  tail -n 30 "$probe_log" >&2
  return 1
}

run_probe login-a
run_probe restore-a
run_probe logout
run_probe restore-signed-out
run_probe login-a
run_probe switch-b
run_probe restore-b
run_probe cleanup
echo 'PASS Android acknowledged login/logout/account-switch process restart durability'

# Failure evidence is separate from durability evidence. Corrupt the backing
# XML with the process stopped, then exercise a fresh native initialization.
# Keep the original encrypted file inside the app sandbox and restore it even
# if the corruption assertion fails. No token/ciphertext is printed or exported.
probe_preferences='shared_prefs/FlutterSecureStorage.xml'
probe_backup='files/auth-probe-prefs-backup'
"$probe_adb" -s "$probe_serial" shell run-as "$probe_package" cp "$probe_preferences" "$probe_backup"
restore_preferences() {
  "$probe_adb" -s "$probe_serial" shell am force-stop "$probe_package"
  "$probe_adb" -s "$probe_serial" shell run-as "$probe_package" cp "$probe_backup" "$probe_preferences"
  "$probe_adb" -s "$probe_serial" shell run-as "$probe_package" rm "$probe_backup"
}
trap 'restore_preferences; rm -f "$probe_log"' EXIT
"$probe_adb" -s "$probe_serial" shell "run-as $probe_package sh -c 'printf %s malformed-xml > $probe_preferences'"
run_probe restore-error
"$probe_adb" -s "$probe_serial" shell run-as "$probe_package" cp "$probe_backup" "$probe_preferences"
# Keep XML well-formed and damage only the synthetic session ciphertext.
"$probe_adb" -s "$probe_serial" shell "run-as $probe_package sed -i 's#\(<string name=\"[^\"]*binblog.khuonvien.vn.session.v1\">\)[^<]*#\1invalid!#' $probe_preferences"
"$probe_adb" -s "$probe_serial" shell "run-as $probe_package grep -q 'invalid!' $probe_preferences"
run_probe restore-error
restore_preferences
trap 'rm -f "$probe_log"' EXIT
run_probe restore-signed-out
echo 'PASS Android corrupt preference XML and ciphertext propagate as recoverable restoring errors'
