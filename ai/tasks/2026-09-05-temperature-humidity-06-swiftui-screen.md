# Task 06 — Build SwiftUI Temperature/Humidity Detail Screen

## Status

Planned.

## Goal

Build a dedicated, accessible SwiftUI screen that presents realtime environmental readings without exposing actuator controls that the sensor does not support.

## Scope

- SwiftUI presentation only.
- Realtime local/simulated MVP.
- Consume `TemperatureHumidityDetailViewModel`; do not call simulator, APIs, or hardware directly.

## Prerequisites

- Task 05: tested view model exists.
- Task 01: product decisions and sensor capabilities are confirmed.

## Expected Files

- Create `kvx/Views/TemperatureHumidityDetailView.swift`
- Optionally create small sensor-specific reusable views under `kvx/Views/` only when reuse/readability justifies them
- Add representative `#Preview` states where practical

## Recommended Layout

1. Device header
   - Sensor name
   - Device status
   - Sensor icon
2. Measurement area
   - Temperature card with value and `°C`
   - Relative humidity card with value and `%`
3. Freshness area
   - Measurement or received timestamp with accurate semantics
   - Current/stale indication
4. Feedback states
   - Waiting for first event
   - Empty reading
   - Partial reading
   - Stream error with reconnect
   - Reconnecting without blanking current content
5. Sensor metadata
   - Stable device ID and only other confirmed useful fields

## UI Rules

- Show `--` or a clear unavailable label for each missing metric; never display `0` as a fallback.
- Do not label a received-at timestamp as measured-at.
- Do not add comfort labels such as “good,” “hot,” or “humid” without approved thresholds.
- Do not show the existing switch control or schedule section unless Task 01 confirms the sensor supports them.
- Use semantic colors and SF Symbols.
- Support Dynamic Type, VoiceOver, light mode, and dark mode.
- Icon-only controls require accessibility labels.
- Reconnect must invoke the view model, not a simulator/data source.

## Relevant Existing Files

- `kvx/Views/DeviceDetailView.swift`
- `kvx/Views/DeviceListView.swift`
- `kvx/Models/Device.swift`
- `kvx/ViewModels/TemperatureHumidityDetailViewModel.swift`

## Acceptance Criteria

- [ ] Device identity and connection status are visible.
- [ ] Temperature is shown with an explicit unit when available.
- [ ] Humidity is shown with an explicit unit when available.
- [ ] Missing metrics are shown as unavailable, not zero.
- [ ] Reading freshness/timestamp is visible and semantically correct.
- [ ] Waiting, empty, error, partial, stale, connected, and reconnecting states render correctly.
- [ ] Reconnect is available after stream failure, and current content remains visible when possible.
- [ ] No raw API or hardware call exists in the view.
- [ ] Unsupported control and schedule UI is absent.
- [ ] The screen supports accessibility and light/dark appearance.

## Verification

- Inspect all representative previews.
- Build for an iOS Simulator.
- Manually verify large Dynamic Type, VoiceOver labels, light mode, and dark mode.
- Report each check as PASS, FAIL, or NOT PERFORMED.

## Risks / Limitations

- Avoid introducing a chart library; charts are outside the MVP.
- Long localized values and accessibility sizes may require vertical card stacking rather than fixed horizontal sizing.

## Out of Scope

- Charts and historical summaries
- Alert thresholds
- Unit preferences
- Production transport and background observation
