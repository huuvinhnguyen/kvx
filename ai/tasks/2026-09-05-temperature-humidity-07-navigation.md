# Task 07 — Integrate Temperature Sensor Navigation

## Status

Planned.

## Goal

Route temperature sensors to the dedicated sensor detail screen while preserving the existing detail flow and list behavior for all other device types.

## Scope

- Swift navigation and dependency composition only.
- Minimal conditional routing in the existing device list.

## Prerequisites

- Task 06: sensor detail screen is available.
- Concrete repository/use case dependencies from Tasks 03–05 can be constructed at the composition boundary.

## Architecture Decision

Use conditional destination selection in the existing list for now:

- `.temperature` -> `TemperatureHumidityDetailView`
- Other device types -> existing `DeviceDetailView`

Do not introduce a routing framework or generalized detail router until multiple additional specialized detail screens justify that abstraction.

## Relevant Existing Files

- `kvx/Views/DeviceListView.swift`
- `kvx/Views/DeviceDetailView.swift`
- `kvx/ContentView.swift`
- `kvx/kvxApp.swift`

## Required Changes

- Select the destination based on `Device.DeviceType`.
- Supply the sensor detail dependency through the existing app composition flow.
- Remove the temporary temperature sensor debug HUD in `DeviceListView` after the real flow is available.
- Preserve search, filtering, pull-to-refresh, add-device, delete, and non-sensor navigation behavior.
- Do not redesign `NavigationStack` or add a dependency unless approved.

## Acceptance Criteria

- [ ] Tapping a `.temperature` device opens the dedicated sensor screen.
- [ ] Tapping iPhone, iPad, simulator, and switch devices opens the existing detail screen.
- [ ] The correct stable device ID reaches the sensor use case.
- [ ] Dependencies are created at an appropriate composition boundary.
- [ ] The temporary sensor debug HUD is removed.
- [ ] Search and filtering still work.
- [ ] Pull-to-refresh still works.
- [ ] Adding and deleting devices still work.
- [ ] No unrelated navigation architecture is introduced.

## Verification

- Build the Swift target.
- Manually navigate using at least one temperature and one non-temperature device.
- Exercise search, filters, refresh, add, and delete flows.
- Add a focused UI test when deterministic test data can be injected.
- Report actual results; do not infer unrun behavior.

## Risks / Limitations

- The current remote API mapper may produce no reading until Task 03 is backed by a verified contract.
- Avoid constructing a new repository repeatedly on every SwiftUI body evaluation; keep dependency lifetime explicit.

## Out of Scope

- Replacing all navigation with a router/coordinator
- Updating Flutter navigation
- Refactoring unrelated list components
