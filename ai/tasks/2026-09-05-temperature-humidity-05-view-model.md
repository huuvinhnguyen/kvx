# Task 05 — Add Temperature/Humidity Detail View Model

## Status

Planned.

## Goal

Create a testable `@Observable` state holder for the sensor detail screen, including stream startup, realtime events, partial readings, stale state, empty state, failure, reconnect, and cancellation.

## Scope

- Swift presentation state only.
- Start, observe, retry/reconnect, and cancel a realtime stream.
- No background monitoring after the detail flow stops observing.

## Prerequisites

- Task 04: environmental reading stream use case exists.
- Freshness threshold and stream failure behavior are defined in Task 01.

## Relevant Existing Files

- `kvx/ViewModels/DeviceViewModel.swift`
- `kvx/Models/Device.swift`

## Expected Files

- Create `kvx/ViewModels/TemperatureHumidityDetailViewModel.swift`
- Add `TemperatureHumidityDetailViewModelTests.swift` under `kvxTests/`

## Recommended State Model

Use an explicit state representation rather than unrelated Boolean flags. It must distinguish:

- Idle before observation starts
- Waiting for the first stream event
- Loaded current reading
- Loaded stale reading
- Empty/no reading
- Failed before any valid reading
- Connected and receiving new events
- Stream failed while preserving the last known reading
- Reconnecting while preserving the last known reading
- Observation cancelled/stopped

The view model should own request coordination and presentation-safe state, but it must not call a raw API or hardware SDK.

## Behavior

- Observe only the supplied stable device ID.
- Prevent duplicate active subscriptions.
- Clear obsolete full-screen errors before reconnecting.
- Apply valid events in arrival order.
- Preserve the last valid reading when a malformed event or stream failure occurs.
- Expose an explicit retry/reconnect operation; do not add an unbounded retry loop.
- Cancel the observation task when it is stopped or replaced.
- Determine freshness from the five-minute rule and an injectable clock so tests are deterministic.
- Refresh stale/current presentation as time advances even if no new event arrives, without polling the data source.
- Do not convert missing temperature/humidity to zero.

## Acceptance Criteria

- [ ] The view model is `@Observable` and receives its stream use case through initializer injection.
- [ ] Waiting, connected, loaded, empty, stale, failed, reconnecting, and stopped states are distinct where needed.
- [ ] Partial readings remain representable.
- [ ] Events update state in arrival order.
- [ ] Stream failure does not discard the last known reading.
- [ ] Duplicate active subscriptions are prevented.
- [ ] Retry/reconnect replaces the failed subscription safely.
- [ ] Stop/deinitialization cancels observation and freshness work.
- [ ] Freshness behavior is deterministic in tests and changes after five minutes without a new sensor event.
- [ ] The view model contains no API, persistence, simulator, or hardware code.
- [ ] State transition tests cover every listed behavior.

## Verification

Run focused view-model tests, followed by the Swift test suite. Report actual commands and results.

## Risks / Limitations

- Avoid storing a detached copy of generic device collection state in this view model.
- If device status also needs live updates, its ownership must be explicitly decided rather than silently duplicated.
- Any timer used only to recompute freshness must be cancellation-aware and must not poll the repository.
- Automatic exponential reconnect or background observation requires separate approval.

## Out of Scope

- SwiftUI layout
- Navigation
- Transport-specific streaming code
- Background execution
