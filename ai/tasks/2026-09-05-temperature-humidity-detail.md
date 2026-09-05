# Temperature and Humidity Detail — Task Index

## Goal

Deliver a dedicated SwiftUI detail experience for temperature and humidity sensors while preserving existing behavior for all other device types.

## Target Platform

- Primary: Swift / SwiftUI
- Flutter parity: separate follow-up after the Swift contract and behavior are stable

## Recommended MVP

- Show the current temperature and relative humidity reading.
- Observe realtime updates from an initial local/simulated source.
- Show device status and reading timestamp/freshness.
- Mark readings older than five minutes as stale.
- Handle loading, empty, partial, stale, stream-failure, and reconnect states.
- Do not add history charts, alerts, background monitoring, or actuator controls.

## Execution Order

Tasks are ordered by dependency. Do not begin an implementation task until its prerequisites are complete.

| Order | Task | Depends on | Deliverable |
|---|---|---|---|
| 1 | [01 — Confirm requirements and API contract](2026-09-05-temperature-humidity-01-requirements-api-contract.md) | None | Verified sensor contract and MVP decisions |
| 2 | [02 — Define sensor reading domain model](2026-09-05-temperature-humidity-02-domain-model.md) | Task 1 | Framework-independent entity and stream repository contract |
| 3 | [03 — Implement sensor data adapter](2026-09-05-temperature-humidity-03-data-adapter.md) | Tasks 1–2 | Local/simulated realtime adapter |
| 4 | [04 — Add reading stream use case](2026-09-05-temperature-humidity-04-use-case.md) | Tasks 2–3 | Application operation for observing readings |
| 5 | [05 — Add detail view model](2026-09-05-temperature-humidity-05-view-model.md) | Task 4 | Observable, testable screen state holder |
| 6 | [06 — Build SwiftUI sensor detail screen](2026-09-05-temperature-humidity-06-swiftui-screen.md) | Task 5 | Dedicated accessible sensor UI |
| 7 | [07 — Integrate sensor navigation](2026-09-05-temperature-humidity-07-navigation.md) | Task 6 | Conditional routing without regressions |
| 8 | [08 — Verify and document](2026-09-05-temperature-humidity-08-testing-documentation.md) | Tasks 1–7 | Tests, build verification, and current documentation |

## Shared Constraints

- Follow `ai/PROJECT.md`, `ai/ARCHITECTURE.md`, and `ai/CONVENTIONS.md`.
- Work only on the active task file.
- Prefer existing abstractions and keep changes minimal.
- Do not silently redesign the project.
- Keep hardware-specific behavior behind an interface or adapter.
- Do not hard-code or expose credentials and tokens.
- Do not add dependencies without approval.
- Do not commit or push unless explicitly requested.

## Definition of Done

- A temperature device opens the dedicated sensor detail screen.
- Temperature and humidity values stream through clean architecture boundaries from the local/simulated source.
- Reading freshness is visible, readings older than five minutes are marked stale, and missing values are not represented as zero.
- Loading, error, empty, partial, stale, reconnect, and cancellation states are covered.
- Non-temperature devices retain their existing detail behavior.
- Relevant tests and documentation are complete and actual verification results are reported.
