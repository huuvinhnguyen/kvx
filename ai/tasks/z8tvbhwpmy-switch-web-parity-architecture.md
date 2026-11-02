# Switch mobile phase 1 — implementation handoff

Task: https://app.clickup.com/t/z8tvbhwpmy . Base main0908e7a.
Owner approved backend phase1 closure and mobile implementation. Backend PR120,
production cf57be9; owner supplied migration/index, flag, nonadmin GET/ownership
and safe-device ON/OFF/pulse evidence. Backend completion does not unlock reminders.
Latest ClickUp phase1 decision supersedes historical full-parity blockers.

## Contract and approach

Use `/api/switches/{database Device.id}` only, authenticated via existing
session-generation transport. No MQTT/legacy API, no auto retries. Relay indices
0-based. Detail relays nullable state; online unknown, physical_state_verified=false.
Reuse existing Buzzer composition pattern: dedicated SwitchRepository contract,
use cases, authenticated implementation, observable ViewModel/Provider, dedicated
Switch screen selected by existing device-detail routing. Existing RelayChannel,
RelayReminder and RelayStatistics require nonnullable/physical-runtime assumptions;
keep them for existing demos and use facade-specific snapshot/read models to avoid
inventing OFF, valid schedules or physical runtime. No dependency upgrades.

GET detail; POST relays/{index}/state integer switch_value0/1; POST pulse integer
duration_ms1000..86400000 multiple1000; POST refresh bodyless; GET reminders with
limit100/after_id cursor and load-more (ID order on wire, start-time/ID display sort);
GET statistics default server7days+07, log_records counts only. Use server limits.
Reminder writes remain absent from repository and UI regardless returned capability.
Render once/daily/weekly/monthly/unknown and invalid legacy schedules read-only.
Dates display explicitly UTC+07, not phone timezone. Shared synthetic backend fixtures.

## State, errors and safety

Load/error/empty/stale states, per-relay selection. Whole-screen mutation lock
prevents conflicting relay/device refresh/select commands; no optimistic state,
countdown or ACK fiction. On200 accepted/publish_returned/none show publish-only
notice and GET snapshot.502/network/malformed mutation response => outcome unknown;
no replay. GET cannot prove physical state: keep uncertainty warning, require a
successful read plus explicit operator reconciliation before a deliberate new
command. A failed read blocks commands. Read retry never POST refresh implicitly.
Separate buttons for GET reload and POST device refresh.401 uses existing session
invalidation; generation transport and view lifecycle discard stale responses.

## Files and verification

Each platform: models, repository interface, use cases, data adapter, state holder,
screen; wire session composition/navigation. Tests: actual synthetic fixtures,
method/path/body/Bearer/session/error/invalid schemas, duration bounds, duplicate
mutation, unknown outcome/reload/explicit reconciliation, stale completions and
relay selection, widget/screen behavior. No production commands for implementation.
Flutter analyze/test; Swift build/XCTest/UI tests require macOS/Xcode; label missing
toolchains honestly. Independent Reviewer then Final Verifier per Binblog workflow.
No commit/push without explicit authorization per kvx developer guide.

## Acceptance / rollout

Phase1 only: server-backed detail/manual commands/pulse/refresh/read reminders/stats
aligned Swift+Flutter; reminder writes locked. Preserve PIR/Buzzer/auth flows.
After merge, mobile simulator/device/manual parity remains required; backend smoke
is not mobile E2E proof. Roll back mobile code, never replay commands or delete
server data. Reminder phase2 z8tvbhwywq; follow-up Swagger/smoke z8tvbhwywr.
