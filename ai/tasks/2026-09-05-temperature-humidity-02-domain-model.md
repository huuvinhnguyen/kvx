# Task 02 — Define Environmental Reading Domain Model

## Status

Completed on 2026-09-06.

Commit: `4b5d66b`

## Goal

Introduce a framework-independent representation of temperature/humidity readings and a repository contract that can be implemented by API or hardware adapters.

## Scope

- Swift domain layer only.
- Realtime reading stream capability required by the approved MVP.
- Preserve current `Device` behavior during migration.

## Prerequisites

- Task 01 is complete and the data semantics are confirmed.

## Architecture Decision

Prefer a separate `EnvironmentalReading` entity instead of adding timestamp, freshness, history, and transport details to `Device`.

Recommended conceptual fields:

- Stable `deviceId`
- Optional temperature value stored canonically in Celsius
- Optional relative humidity stored as percent
- Measurement timestamp, according to the confirmed contract
- Any source-receipt timestamp only if required and clearly named

The repository contract should expose a cancellation-aware asynchronous stream of readings by stable device ID. Domain code must not reference SwiftUI, URLSession, JSON, MQTT, Bluetooth, or a concrete SDK.

## Relevant Existing Files

- `kvx/Models/Device.swift`
- `kvx/Domain/Repositories/DeviceRepository.swift`
- `ai/ARCHITECTURE.md`

## Expected Files

- Create `kvx/Models/EnvironmentalReading.swift`
- Create `kvx/Domain/Repositories/EnvironmentalSensorRepository.swift`
- Add domain tests in `kvxTests/`, preferably dedicated test files

Do not remove `Device.temperature` or `Device.humidity` in this task. Their cleanup is a separate migration after the new flow is stable.

## Implementation Notes

- Missing temperature and missing humidity must be distinguishable from numeric zero.
- Formatting, colors, comfort labels, and SF Symbols do not belong in the entity.
- Validation policy must follow Task 01. Invalid transport values should normally be rejected or mapped before entering domain state.
- Repository errors may be typed if the contract needs callers to distinguish no-reading from transport failure.

## Acceptance Criteria

- [ ] The entity has no UI, network, persistence, or hardware dependency.
- [ ] Temperature and humidity units are explicit and unambiguous.
- [ ] Partial readings are representable.
- [ ] Missing values are not converted to zero.
- [ ] Reading time semantics match the confirmed contract.
- [ ] Repository observes a cancellation-aware reading stream by stable `deviceId`.
- [ ] Existing `Device` functionality remains unchanged.
- [ ] Domain tests cover full, partial, boundary, and equality behavior as applicable.

## Verification

Suggested checks:

```bash
xcodebuild test \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Report the actual command and result. If unavailable, report `NOT RUN`.

## Risks / Limitations

- Avoid overgeneralizing the model for unconfirmed sensor types.
- Do not add history collections to the latest-reading entity.
- Do not add a third-party dependency for simple domain modeling.

## Out of Scope

- DTO mapping
- Concrete repository implementation
- View model and UI
- Removing legacy sensor fields from `Device`
