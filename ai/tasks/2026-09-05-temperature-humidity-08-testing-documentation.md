# Task 08 — Verify and Document Temperature/Humidity Detail

## Status

Planned.

## Goal

Verify the complete Swift sensor detail flow, add regression coverage, and document the final API, hardware, architecture, and product behavior.

## Scope

- Swift tests and documentation for Tasks 01–07.
- No new product features.

## Prerequisites

- Tasks 01–07 are implemented.

## Test Coverage

### Domain and Mapping

- Full temperature and humidity reading
- Temperature-only reading
- Humidity-only reading
- No reading
- Boundary humidity values
- Invalid/non-finite values
- Timestamp parsing and semantics
- API/hardware errors

### Use Case and View Model

- Successful stream startup
- Event order and device ID scoping
- Empty reading
- Initial failure and reconnect
- Current versus stale reading
- Stream events while content remains visible
- Failed stream retains last reading
- Duplicate subscription prevention
- Cancellation stops observation

### UI and Navigation

- Temperature device opens the sensor screen
- Other devices retain existing detail destination
- Waiting, empty, partial, stale, connected, and reconnecting states are understandable
- Stream events arrive while the screen is visible
- Missing metric is not shown as zero
- Accessibility labels and Dynamic Type
- Light and dark appearance

### Regression

- Device loading
- Search
- Status filtering
- Pull-to-refresh
- Add device
- Delete device
- Existing non-temperature detail screen

## Relevant Existing Files

- `kvxTests/`
- `kvxUITests/`
- `BUILD.md`
- `docs/requirements/`
- `docs/api/`
- `docs/hardware/`
- `docs/architecture/overview.md`
- `docs/decisions/`

## Documentation Deliverables

- Requirement document with MVP and explicit non-goals.
- Confirmed local/simulated contract with field semantics.
- Simulator behavior describing units, ranges, freshness, and failure modes.
- Architecture overview update if the final stream implementation differs from the current documented flow.
- ADR only if a significant long-lived architectural decision was made.

## Verification Commands

Use an available simulator destination rather than assuming one exists. Typical commands:

```bash
xcodebuild \
  -project kvx.xcodeproj \
  -scheme kvx \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```bash
xcodebuild test \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Before finishing:

```bash
git status
git diff
```

Review every modified or created file. Do not commit or push unless explicitly requested.

## Acceptance Criteria

- [ ] Swift target builds successfully.
- [ ] Domain, mapping, use-case, and view-model tests pass.
- [ ] Critical sensor navigation/UI tests pass or manual verification is explicitly reported.
- [ ] Non-temperature device flow is unchanged.
- [ ] Missing, partial, stale, offline, and error data are handled.
- [ ] Accessibility and light/dark checks are complete or marked `NOT PERFORMED`.
- [ ] Confirmed local contract documentation matches the verified implementation.
- [ ] No credential, token, key, or secret is present in fixtures, logs, or documentation.
- [ ] `git status` and `git diff` have been reviewed.

## Final Report Requirements

Report:

- Summary
- Every changed or created file
- Important implementation decisions
- Exact build/test commands and outcomes
- Acceptance criteria checklist
- Risks and limitations
- Out-of-scope issues intentionally not changed

## Risks / Limitations

- Simulator validation is not physical hardware validation; physical accuracy, real connectivity, and production transport cannot be verified by this task.
- A deterministic simulator does not prove wall-clock timing or unbounded stream lifetime.

## Out of Scope

- New charts, alerts, production transport, background observation, or settings discovered during verification
- Flutter parity implementation
- Unrelated defects; report them and propose separate tasks
