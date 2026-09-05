# Environmental Reading Contract

## Status

Approved local/simulated contract. No production BinBlog sensor endpoint or streaming protocol has been confirmed.

## Source

The initial implementation uses an in-process local/simulated source. It emits realtime events through an asynchronous, cancellation-aware interface. A future BinBlog, WebSocket, MQTT, Bluetooth, or other hardware adapter must map its payload into the same semantic contract.

## Canonical Reading Shape

The following JSON is a sanitized documentation representation. It defines field semantics for fixtures and future adapters; it does not imply that a network endpoint currently exists.

```json
{
  "device_id": "sensor-001",
  "temperature_celsius": 24.5,
  "relative_humidity_percent": 58.0,
  "measured_at": "2026-09-05T12:00:00Z"
}
```

A partial reading is valid:

```json
{
  "device_id": "sensor-001",
  "temperature_celsius": 24.5,
  "relative_humidity_percent": null,
  "measured_at": "2026-09-05T12:00:05Z"
}
```

## Field Mapping

| Field | Type | Required | Unit / Format | Validity |
|---|---|---:|---|---|
| `device_id` | String | Yes | Stable device identifier | Must be non-empty and match the subscribed device |
| `temperature_celsius` | Number or null | No | Degrees Celsius | Must be finite; no narrower physical range is assumed until hardware is selected |
| `relative_humidity_percent` | Number or null | No | Percent | Must be finite and within `0...100`, inclusive |
| `measured_at` | String | Yes | RFC 3339 / UTC in documented JSON fixtures | Must parse to an absolute instant |

At least one of `temperature_celsius` or `relative_humidity_percent` must be present for a measurement event to be useful. An event with both values absent is treated as no reading rather than a numeric reading.

## Timestamp Semantics

- `measured_at` means the time the sensor reading was measured.
- It must not be replaced with UI render time.
- If a future source exposes only server receipt time, map it to a separately named field rather than claiming it is measurement time.
- A reading is stale when `currentTime - measuredAt > 5 minutes`.
- Implementations should reject or flag timestamps unreasonably far in the future; the exact clock-skew tolerance belongs in the implementation task and must be tested.

## Delivery Contract

Conceptually, a repository exposes a stream for one device:

```text
observeLatestReading(deviceId) -> asynchronous stream of reading events
```

Required behavior:

- Subscription is non-blocking.
- Events are scoped to the requested stable device ID.
- Cancellation stops local generation or releases the underlying production subscription.
- Only one active subscription is needed per detail screen instance.
- A malformed event does not terminate the process or overwrite the last valid reading.
- A terminal source failure is surfaced distinctly from “no reading yet.”
- Reconnection is initiated explicitly by the presentation/application flow for the MVP; unbounded retry loops are not part of this contract.

## Local/Simulated Source

The simulator must:

- Require no authentication.
- Produce deterministic values/timing when supplied a deterministic fixture or clock.
- Support full and partial reading fixtures.
- Support no-reading and failure scenarios for tests/previews.
- Respect cancellation.
- Avoid blocking threads while waiting between events.

A default demo sequence may be provided for manual use, but tests must not depend on random values or wall-clock timing.

## Authentication

- Local source: none.
- Production source: not yet confirmed.
- Future adapters must reuse the appropriate credential provider and must never log token or credential values.

## Endpoint / Protocol

No production endpoint or protocol is defined for the MVP. The existing `GET /api/devices` endpoint is confirmed only for device listing by current source code; it does not currently map sensor readings.

A future production adapter requires a separate contract update documenting:

- Endpoint, topic, service, or SDK call
- Authentication
- Request/subscription shape
- Event envelope and field types
- Error and close codes
- Heartbeat and reconnect behavior
- Rate limits or sampling cadence

## Error Categories

The implementation should preserve these semantic outcomes:

- Waiting for first reading
- No reading available
- Invalid/malformed event
- Source unavailable
- Authentication failure, for future remote sources
- Subscription ended unexpectedly
- Cancellation requested by the caller

Transport-specific errors must be translated at the adapter boundary.

## Security

- Examples use synthetic identifiers and values.
- Do not include Authorization headers, passwords, access tokens, private keys, or real customer payloads in fixtures or logs.
