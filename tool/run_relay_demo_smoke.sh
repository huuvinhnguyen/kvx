#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "This smoke requires an iPhone Simulator on macOS." >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
export RELAY_SMOKE_ARTIFACT_DIR="${RELAY_SMOKE_ARTIFACT_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/relay-demo-artifacts}"
mkdir -p "$RELAY_SMOKE_ARTIFACT_DIR"
stage="${1:-all}"
if [[ "$stage" == all ]]; then
  for step in prepare build boot drive; do
    bash "$0" "$step"
  done
  exit 0
fi
case "$stage" in prepare|build|boot|drive) ;; *) echo "Unknown smoke stage: $stage" >&2; exit 1 ;; esac
if [[ "$stage" == prepare ]]; then
  git -C "$root" rev-parse HEAD > "$RELAY_SMOKE_ARTIFACT_DIR/checkout-sha.txt"
  smoke_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kvx-relay-smoke.XXXXXX")"
  python3 "$root/tool/relay_smoke_support.py" prepare "$root" "$smoke_dir"
  cd "$smoke_dir"
  flutter pub get
  python3 "$root/tool/relay_smoke_support.py" check-lock "$root" "$smoke_dir" > "$RELAY_SMOKE_ARTIFACT_DIR/dependencies.json"
  flutter analyze integration_test test_driver
  printf '%s\n' "$smoke_dir" > "$RELAY_SMOKE_ARTIFACT_DIR/smoke-dir.txt"
  exit 0
fi
smoke_dir="$(cat "$RELAY_SMOKE_ARTIFACT_DIR/smoke-dir.txt")"
[[ -d "$smoke_dir/integration_test" ]] || { echo "Prepared smoke app missing" >&2; exit 1; }
cd "$smoke_dir"
app="$smoke_dir/build/ios/iphonesimulator/Runner.app"
if [[ "$stage" == build ]]; then
  # Build against the generic simulator destination before starting a device.
  flutter build ios --simulator --debug --no-codesign --no-pub \
    --target=integration_test/relay_demo_smoke_test.dart --verbose \
    2>&1 | tee "$RELAY_SMOKE_ARTIFACT_DIR/build.log"
  codesign --force --deep --sign - --timestamp=none "$app"
  codesign --verify --deep --strict "$app"
  exit 0
fi
if [[ "$stage" == boot ]]; then
xcrun simctl list devices available --json > "$RELAY_SMOKE_ARTIFACT_DIR/simulators.json"
simulator_id="$(python3 - "$RELAY_SMOKE_ARTIFACT_DIR/simulators.json" <<'PY'
import json,sys
available=json.load(open(sys.argv[1]))['devices']
phones=[d for runtime, devices in available.items() if 'iOS' in runtime for d in devices if d['name'].startswith('iPhone') and d.get('isAvailable', True)]
if not phones: raise SystemExit('No available iPhone Simulator')
phones.sort(key=lambda d: (d['state'] != 'Booted', d['name']))
print(phones[0]['udid'])
PY
)"
xcrun simctl bootstatus "$simulator_id" -b
open -a "$(xcode-select -p)/Applications/Simulator.app" --args -CurrentDeviceUDID "$simulator_id"
printf '%s\n' "$simulator_id" > "$RELAY_SMOKE_ARTIFACT_DIR/selected-simulator.txt"
exit 0
fi
simulator_id="$(cat "$RELAY_SMOKE_ARTIFACT_DIR/selected-simulator.txt")"
[[ -d "$app" ]] || { echo "Prebuilt simulator app missing" >&2; exit 1; }
# Target launches only local demo widgets, never the authenticated app graph.
flutter drive --driver=test_driver/relay_demo_smoke_driver.dart \
  --target=integration_test/relay_demo_smoke_test.dart \
  --device-id "$simulator_id" --use-application-binary="$app" --no-pub --verbose 2>&1 | tee "$RELAY_SMOKE_ARTIFACT_DIR/smoke.log"
python3 - "$RELAY_SMOKE_ARTIFACT_DIR" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1])
states=['01_initial','02_on','03_off','04_reminder_form','05_added','06_group_off','07_group_on','08_deleted']
expected={f'{mode}_{state}.png' for mode in ['light','dark'] for state in states}
actual={p.name for p in root.glob('*.png')}
if actual!=expected: raise SystemExit(f'Unexpected screenshot set: missing={expected-actual}, extra={actual-expected}')
result=json.loads((root/'result.json').read_text())
if result.get('completed_modes')!=['light','dark']: raise SystemExit('Incomplete simulator flow')
print('SIMULATOR_SMOKE_PASS: light/dark ON/OFF, add/delete and reminder group;16 screenshots')
PY
