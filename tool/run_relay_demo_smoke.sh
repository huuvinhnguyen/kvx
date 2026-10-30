#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "This smoke requires an iPhone Simulator on macOS." >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
export RELAY_SMOKE_ARTIFACT_DIR="${RELAY_SMOKE_ARTIFACT_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/relay-demo-artifacts}"
mkdir -p "$RELAY_SMOKE_ARTIFACT_DIR"
git -C "$root" rev-parse HEAD > "$RELAY_SMOKE_ARTIFACT_DIR/checkout-sha.txt"
smoke_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kvx-relay-smoke.XXXXXX")"
python3 "$root/tool/relay_smoke_support.py" prepare "$root" "$smoke_dir"
cd "$smoke_dir"
flutter pub get
python3 "$root/tool/relay_smoke_support.py" check-lock "$root" "$smoke_dir" > "$RELAY_SMOKE_ARTIFACT_DIR/dependencies.json"
flutter analyze integration_test test_driver

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
open -a Simulator
xcrun simctl bootstatus "$simulator_id" -b
printf '%s\n' "$simulator_id" > "$RELAY_SMOKE_ARTIFACT_DIR/selected-simulator.txt"
# Target launches only local demo widgets, never the authenticated app graph.
flutter drive --driver=test_driver/relay_demo_smoke_driver.dart \
  --target=integration_test/relay_demo_smoke_test.dart \
  --device-id "$simulator_id" --no-pub 2>&1 | tee "$RELAY_SMOKE_ARTIFACT_DIR/smoke.log"
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
