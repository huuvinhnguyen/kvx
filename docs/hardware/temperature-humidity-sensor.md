# Temperature and Humidity Sensor Behavior

## Status

Initial simulated-hardware specification. The physical sensor model and production transport are not yet selected.

## Supported Capability

The initial environmental sensor is read-only and reports:

- Temperature in degrees Celsius
- Relative humidity as a percentage
- The time at which the reading was measured

It does not support:

- Power control from the app
- Scheduling
- Threshold automation
- Historical storage
- Background notifications

## Data Characteristics

| Measurement | Representation | Rules |
|---|---|---|
| Temperature | Finite decimal in `°C` | May be absent independently; no hardware-specific min/max until a sensor is selected |
| Relative humidity | Finite decimal percent | May be absent independently; valid range is `0...100` inclusive |
| Measurement time | Absolute timestamp | Required; used to determine freshness |

An absent value is unknown, not zero.

## Realtime Simulation

Until hardware or a production backend is selected, an in-process simulator represents the hardware boundary.

The simulator must:

- Emit readings asynchronously without blocking a thread.
- Scope readings to a stable device ID.
- Stop producing events after cancellation.
- Support deterministic fixtures for automated tests.
- Simulate full, partial, empty, stale, malformed, and failure scenarios.
- Avoid requiring credentials or network connectivity.

Random readings may be useful for a manual demo but must not be the only mode and must not be used in deterministic tests.

## Freshness and Offline Behavior

- A reading is stale when it is more than five minutes old.
- Connection status and reading freshness are separate concepts.
- If a device goes offline after a valid reading, retain the last known reading and label it stale when appropriate.
- Do not erase a valid last-known value solely because the source disconnects.
- If no valid reading has ever arrived, display a no-reading or source-error state rather than fabricated data.

## Lifecycle

- Start observation when the detail flow needs realtime values.
- Avoid duplicate subscriptions for one screen instance.
- Cancel observation when the screen/view model no longer needs it.
- A future hardware adapter must release Bluetooth, MQTT, socket, notification, or SDK resources on cancellation.

## Failure Modes

The UI/application layer must be able to distinguish:

- Waiting for the first sample
- No sample available
- Partial sample
- Stale sample
- Invalid sample
- Source disconnected or failed
- User/system cancellation

Invalid samples must not crash the app or replace the last valid sample.

## Physical Hardware Questions

Before implementing a physical adapter, document:

- Sensor make/model and firmware
- Accuracy, precision, and supported measurement range
- Sampling interval and latency
- Connection method and required permissions
- Pairing/provisioning process
- Disconnection and reconnection behavior
- Clock ownership and timestamp accuracy
- Calibration requirements
- Power/battery behavior
- Whether readings are measured locally or relayed by a server

## Test Procedure for the Local MVP

1. Subscribe to a known simulated sensor ID.
2. Verify full readings arrive in order.
3. Verify temperature-only and humidity-only readings are accepted.
4. Verify humidity outside `0...100` is rejected.
5. Verify a stale timestamp remains visible but is marked stale.
6. Verify a simulated failure preserves the last valid reading.
7. Cancel observation and verify no further event is delivered.

Physical accuracy and connectivity tests must be reported as `NOT PERFORMED` until real hardware is selected.
