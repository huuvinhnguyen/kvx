# Task 01 — Confirm Temperature/Humidity Requirements and Data Contract

## Status

Completed on 2026-09-05 for the local/simulated MVP contract.

A production backend or physical hardware protocol is not yet selected. Production integration remains blocked until its contract is confirmed.

## Goal

Remove ambiguity before implementation by confirming the user experience, data source, payload semantics, units, timestamps, realtime lifecycle, and sensor capabilities.

## Scope

- Platform: Swift planning, with a semantic contract reusable by Flutter later.
- Documentation and investigation only.
- Do not modify production source code.

## Confirmed Decisions

| Question | Decision |
|---|---|
| Initial data source | Local/in-process simulated source; no backend yet |
| Delivery mode | Realtime asynchronous stream while the detail screen observes it |
| Sensor capability | Read-only; no power control or schedules |
| Temperature | Degrees Celsius (`°C`), finite decimal when present |
| Relative humidity | Percent in `0...100`, inclusive, when present |
| Partial data | Temperature or humidity may be absent independently |
| Timestamp | Every useful reading requires `measuredAt` |
| Freshness | Stale when reading age is greater than five minutes |
| History | Excluded from MVP |
| Alerts and automation | Excluded from MVP |
| Authentication | None for the local source; production authentication remains unconfirmed |

## Canonical Local Contract

The documented fixture shape is:

```json
{
  "device_id": "sensor-001",
  "temperature_celsius": 24.5,
  "relative_humidity_percent": 58.0,
  "measured_at": "2026-09-05T12:00:00Z"
}
```

This JSON defines field semantics for local fixtures and future adapter mapping. It does **not** declare a live HTTP endpoint.

The application-facing operation is conceptually:

```text
observeLatestReading(deviceId) -> asynchronous stream of environmental readings
```

## Realtime Rules

- Observation is non-blocking and scoped to a stable device ID.
- The screen displays an initial waiting/loading state until the first event or error.
- A valid event may contain both metrics or only one metric.
- An event with both metrics absent is treated as no reading, not as zero values.
- Invalid events do not replace the last valid reading.
- A stream failure preserves the last valid reading and exposes reconnect/retry behavior.
- Only one active subscription is needed for one detail screen instance.
- Cancellation must stop local event production and release future transport/hardware resources.
- Stale/current presentation must update as time advances even when no new event arrives.

## Deliverables

- [Temperature/humidity product requirements](../../docs/requirements/temperature-humidity-detail.md)
- [Environmental reading contract](../../docs/api/environmental-reading-contract.md)
- [Temperature/humidity simulated hardware behavior](../../docs/hardware/temperature-humidity-sensor.md)

## Relevant Existing Files Reviewed

- `kvx/Services/DeviceAPIClient.swift`
- `kvx/Data/Repositories/RemoteDeviceRepository.swift`
- `kvx/Domain/Repositories/DeviceRepository.swift`
- `kvx/Models/Device.swift`
- `kvx/Views/DeviceListView.swift`
- `BUILD.md`

The current Swift BinBlog implementation confirms only `GET /api/devices` for device listing. Its DTO contains `id`, `name`, `device_type`, and `status`; it does not currently map temperature, humidity, or measurement timestamps. Therefore this endpoint is not treated as a confirmed sensor-reading source.

## Acceptance Criteria

- [x] Initial data source is confirmed as local/simulated.
- [x] Delivery protocol is defined as a realtime asynchronous stream.
- [x] Temperature unit and validity rule are confirmed.
- [x] Humidity representation and valid range are confirmed.
- [x] Missing and malformed-value behavior is defined.
- [x] Measurement timestamp semantics are confirmed for the local contract.
- [x] Offline/failure and stale-reading behavior is defined.
- [x] Sensor capability is explicitly read-only.
- [x] History is explicitly excluded from the MVP.
- [x] Local field names and semantics are defined without guesswork.
- [x] Documentation contains only synthetic values and no credentials or tokens.
- [ ] Production endpoint/protocol and authentication are confirmed; intentionally deferred because no backend or hardware source exists yet.

## Verification Performed

- Compared the documentation with the current Swift source contract.
- Confirmed that existing production code has no sensor-reading endpoint or mapped reading payload.
- Confirmed every local MVP requirement question has an explicit decision.
- Reviewed the new documentation for secret values; examples use synthetic identifiers and measurements.

No build, unit test, network request, or hardware test is required for this documentation-only task.

## Risks / Decisions

- The local field names are canonical application/fixture names, not claims about a future BinBlog payload.
- A production adapter must not be implemented by guessing fields from this local contract.
- Realtime changes the follow-up architecture from a one-shot fetch to a cancellation-aware stream. Tasks 02–08 must use this approved requirement.
- Do not call server receipt time the sensor measurement time unless a future contract guarantees that meaning.

## Out of Scope

- Domain implementation
- Local stream implementation
- Production API or hardware adapter
- View model and UI implementation
- Historical readings and charts
- Alerts, background monitoring, and notifications
- Flutter implementation
