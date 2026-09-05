# Task 03 — Implement Local Realtime Environmental Sensor Adapter

## Status

Planned.

## Goal

Implement the approved local/simulated realtime source and map its events into `EnvironmentalReading` without leaking simulator details into the domain.

## Scope

- Swift data/service layer.
- Realtime readings for one device from a local/in-process simulated source.
- No authentication, network request, or dependency upgrade.

## Prerequisites

- Task 01: confirmed contract.
- Task 02: domain entity and repository interface.

## Approach

Implement the smallest adapter that matches the approved local contract:

- Create an in-process simulated repository implementing the domain stream contract.
- Emit deterministic fixture readings asynchronously for tests and previews.
- Scope every emitted reading to the requested stable device ID.
- Support full, temperature-only, humidity-only, no-reading, stale, malformed, and failure scenarios.
- Respect cooperative cancellation and release stream continuations/tasks when observation ends.
- Keep simulation timing and fixtures injectable so tests do not rely on randomness or wall-clock delays.
- Do not modify `DeviceAPIClient.swift` or the existing BinBlog repository in this task.
- A future production API/hardware adapter requires a separately confirmed contract.

## Relevant Existing Files

- `kvx/Models/Device.swift`
- `kvx/Domain/Repositories/DeviceRepository.swift`
- `docs/api/environmental-reading-contract.md`
- `docs/hardware/temperature-humidity-sensor.md`

## Expected Files

- Create a local/simulated environmental sensor repository under `kvx/Data/Repositories/`.
- Add deterministic fixtures or a small simulator helper only if required by the repository design.
- Add simulator/repository tests in `kvxTests/`.
- Do not modify the current BinBlog API client or authentication provider.

## Error and Validation Rules

- Distinguish waiting/no reading from a simulated source failure.
- Validate humidity as a finite percentage in `0...100`, inclusive.
- Reject or safely handle non-finite temperature values.
- Preserve a partial reading when one valid metric exists.
- Require explicit measurement timestamps; do not invent them inside mapping.
- A malformed simulated event must not crash the process or replace the last valid domain reading.
- No credential, token, or authentication code is required for the local source.

## Acceptance Criteria

- [ ] Local simulated adapter implements the domain stream repository contract.
- [ ] Events follow the approved canonical field semantics and units.
- [ ] Full and partial readings stream correctly.
- [ ] Waiting/no reading is distinct from source failure.
- [ ] Invalid fixture events do not crash the application.
- [ ] Stream production is non-blocking and cancellation-aware.
- [ ] Test behavior is deterministic and does not depend on random values or real-time sleeps.
- [ ] Readings are scoped to the requested device ID.
- [ ] No authentication or secret handling is introduced.
- [ ] Simulator details remain isolated from domain and presentation.

## Verification

- Unit test deterministic sequences for valid, partial, no-reading, stale, malformed, and failure scenarios.
- Verify event order and device ID scoping.
- Verify cancellation stops further delivery and releases producer resources.
- Run the relevant Swift test suite and report the actual result.

## Risks / Limitations

- Avoid adding retry loops at multiple layers; reconnect policy should have one owner.
- Do not assume list status and reading freshness are synchronized.
- A simulator does not validate physical accuracy, connectivity, or production transport behavior.
- Do not modify Flutter data sources in this Swift task.

## Out of Scope

- Production API, WebSocket, MQTT, Bluetooth, or physical hardware integration
- Historical readings
- Background observation
- UI state
- Dependency upgrades
