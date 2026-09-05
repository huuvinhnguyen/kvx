# Task 09 — Flutter Temperature/Humidity Detail Parity

## Status

Deferred follow-up.

## Goal

Bring the approved Swift temperature/humidity domain behavior and user flow to Flutter after the sensor contract and Swift MVP are stable.

## Scope

- Flutter only.
- Preserve platform conventions while matching domain semantics and major user-visible states.

## Prerequisites

- Tasks 01–08 are complete.
- API/hardware contract is documented.
- Any Swift implementation learnings or corrections are reflected in the documentation.

## Likely Affected Files

- `kvx_flutter/lib/domain/entities/device.dart`
- New environmental reading entity and repository contract under `kvx_flutter/lib/domain/`
- New use case under `kvx_flutter/lib/application/usecases/`
- `kvx_flutter/lib/data/models/binblog_device_dto.dart`
- `kvx_flutter/lib/data/datasources/binblog_device_datasource.dart`, or a dedicated sensor data source
- New repository implementation under `kvx_flutter/lib/data/repositories/`
- New provider under `kvx_flutter/lib/presentation/providers/`
- New temperature/humidity detail screen under `kvx_flutter/lib/presentation/screens/`
- `kvx_flutter/lib/presentation/screens/device_list_screen.dart`
- Tests under `kvx_flutter/test/`

## Required Behavior

- Model latest environmental reading separately from stable device metadata.
- Preserve full, partial, missing, stale, and error outcomes.
- Route temperature devices to a dedicated detail screen.
- Do not display actuator controls for a read-only sensor.
- Keep refresh non-blocking and retain the last known reading on refresh failure.
- Match confirmed unit and timestamp semantics.

## Acceptance Criteria

- [ ] Flutter domain semantics match the approved contract.
- [ ] Temperature devices open a dedicated sensor screen.
- [ ] Other device detail behavior remains unchanged.
- [ ] Loading, empty, partial, stale, refreshing, and error states are represented.
- [ ] Missing values are not converted to zero.
- [ ] Provider/use case/repository boundaries follow the existing Flutter architecture.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] No dependency is added without approval.

## Verification

```bash
cd kvx_flutter
flutter analyze
flutter test
```

Manually verify on a representative simulator or device and report actual results.

## Risks / Limitations

- Do not mechanically copy Swift presentation structure; follow Flutter conventions.
- Do not use the current Flutter `Device` entity as the sole telemetry state if that loses timestamp or partial-reading semantics.

## Out of Scope

- New feature expansion beyond the approved Swift MVP
- Cross-platform visual pixel parity
