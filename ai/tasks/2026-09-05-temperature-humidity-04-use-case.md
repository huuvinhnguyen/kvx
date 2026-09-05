# Task 04 — Add Observe Environmental Readings Use Case

## Status

Planned.

## Goal

Provide one application-level operation for observing a cancellation-aware realtime environmental reading stream by device ID.

## Scope

- Swift application/use-case layer only.
- One realtime observation operation.

## Prerequisites

- Task 02: repository contract exists.
- Task 03: a concrete adapter is available for integration verification.

## Relevant Existing Files

- `kvx/Domain/UseCases/FetchDevicesUseCase.swift`
- `kvx/Domain/Repositories/DeviceRepository.swift`

## Expected Files

- Create `kvx/Domain/UseCases/ObserveEnvironmentalReadingsUseCase.swift`
- Add `ObserveEnvironmentalReadingsUseCaseTests.swift` under `kvxTests/`

## Implementation Notes

- Follow the existing callable/execute convention used by Swift use cases unless a separate approved convention supersedes it.
- Depend on `EnvironmentalSensorRepository`, not on a concrete simulator or future transport.
- Accept the stable device ID.
- Return/forward the repository's asynchronous reading stream without converting events to presentation strings.
- Preserve cancellation and meaningful source errors.
- Do not add caching, timers, unit formatting, retry loops, or UI state in this use case.

## Acceptance Criteria

- [ ] Use case depends only on the repository interface.
- [ ] The stable device ID is forwarded correctly.
- [ ] Reading events are forwarded unchanged according to the domain contract.
- [ ] Cancellation reaches the underlying stream.
- [ ] Waiting/no-reading and source failure remain distinguishable.
- [ ] Tests use a fake repository and cover event order, partial readings, failure, and cancellation.
- [ ] No UI, HTTP, persistence, timer, or hardware dependency is introduced.

## Verification

Run the relevant Swift tests and report the actual result:

```bash
xcodebuild test \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Risks / Limitations

- Keep this use case small; do not turn it into a scheduler, retry manager, or stream cache.
- Avoid swallowing typed repository errors that the view model needs to represent correctly.
- Ensure cancellation semantics are explicit and tested.

## Out of Scope

- View model
- Navigation
- UI formatting
- Reconnect policy
- Historical aggregation
