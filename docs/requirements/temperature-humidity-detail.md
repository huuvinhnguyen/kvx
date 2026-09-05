# Temperature and Humidity Detail Requirements

## Status

Approved for the initial local/simulated contract.

A production backend or hardware protocol has not yet been selected. The requirements below define the product behavior and an implementation-neutral contract for the MVP.

## Problem and User Goal

A user needs to open a temperature sensor from the device list and monitor its current temperature and relative humidity. The screen should continue updating while it is visible and must make data freshness clear.

## Scope

- Primary platform: Swift / SwiftUI.
- Dedicated detail screen for devices whose type is `temperature`.
- Read-only sensor: no power control and no scheduling controls.
- Realtime updates backed initially by a local/simulated source.
- Temperature displayed in degrees Celsius.
- Relative humidity displayed as a percentage from 0 through 100.
- A reading becomes stale when its measurement timestamp is more than five minutes old.
- Either measurement may be unavailable independently.

## User Flow

1. The user opens the device list.
2. The user selects a temperature sensor.
3. The app opens the dedicated temperature/humidity detail screen.
4. The screen begins observing the selected sensor's reading stream.
5. New readings replace the displayed values without blocking interaction.
6. The screen shows when the current reading was measured and whether it is stale.
7. Observation stops when the screen no longer needs the stream.

## Functional Requirements

### Sensor Header

- Display device name, sensor icon, and connection status.
- Preserve the stable device ID for all reading requests.

### Measurements

- Display temperature in `°C` when available.
- Display relative humidity in `%` when available.
- Display an unavailable state, such as `--`, for an absent metric.
- Never substitute numeric zero for an absent metric.
- Support temperature-only and humidity-only readings.

### Realtime Behavior

- Subscribe to a non-blocking stream for the selected device.
- Display an initial loading state until the first stream event or error.
- Apply each valid reading in arrival order.
- Keep the last valid reading visible if the stream later fails.
- Expose a retry/reconnect action after failure.
- Avoid duplicate active subscriptions for the same screen instance.
- Cancel the active subscription when the screen/view model is no longer observing it.

### Freshness

- Use the reading's `measuredAt` timestamp, not local display time, to calculate freshness.
- A reading is current when its age is at most five minutes.
- A reading is stale when its age is greater than five minutes.
- Future timestamps beyond an implementation-defined clock-skew tolerance are invalid and must not silently appear current.
- Refresh the stale/current presentation as time advances, even if no new reading arrives.

### Sensor Capability

- The initial sensor is read-only.
- Do not display power, control, or schedule actions.

### Error and Empty States

- Distinguish waiting for the first reading, no reading available, malformed input, and stream failure.
- A malformed event must not crash the app or replace the last valid reading.
- If no valid reading has ever arrived, show an empty/error state with retry as appropriate.

## Non-Functional Requirements

- UI work and stream processing must remain non-blocking.
- Hardware/backend details must remain behind a repository/adapter boundary.
- Domain types must not depend on SwiftUI, URLSession, MQTT, Bluetooth, or another concrete transport.
- The local simulator must be deterministic under tests.
- New UI must support Dynamic Type, VoiceOver, light mode, and dark mode.
- No credentials or tokens may be required by or embedded in the local contract.

## Contract Decisions

| Concern | Decision |
|---|---|
| Initial source | Local/simulated source |
| Delivery model | Realtime asynchronous stream |
| Sensor capability | Read-only |
| Temperature unit | Degrees Celsius (`°C`) |
| Humidity representation | Relative humidity percent (`0...100`) |
| Partial readings | Allowed |
| Measurement timestamp | Required for each reading |
| Stale threshold | More than 5 minutes old |
| History | Not included |
| Alerts/threshold automation | Not included |

## Acceptance Criteria

- [x] The initial data source is defined as local/simulated.
- [x] Realtime behavior is explicitly required.
- [x] Temperature uses Celsius.
- [x] Humidity uses percentage values in the range `0...100`.
- [x] Temperature and humidity may be absent independently.
- [x] The measurement timestamp is required and drives freshness.
- [x] A reading older than five minutes is stale.
- [x] The sensor is read-only.
- [x] History is excluded from the initial scope.
- [x] Error, empty, malformed-event, cancellation, and retry behavior are defined.

## Open Production Questions

Before replacing the local source with production data, confirm:

- Backend endpoint, WebSocket, MQTT topic, Bluetooth service, or hardware SDK.
- Authentication and authorization mechanism.
- Exact payload field names and numeric types.
- Timestamp encoding, timezone, and clock source.
- Event ordering, reconnection, heartbeat, and retry semantics.
- Whether the production source can emit explicit “no reading” events.
- Whether device connection status and telemetry use the same channel.

These questions do not block the local/simulated MVP, but they block a production adapter.

## Non-Goals

- Historical readings or charts
- Temperature/humidity alerts
- Comfort labels or inferred health recommendations
- Celsius/Fahrenheit preference
- Background monitoring or notifications
- Sensor power control
- Sensor schedules
- Flutter implementation
