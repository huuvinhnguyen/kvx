# Task 03 — Relay Control Use Cases

## Status

Ready to start (depends on Task 02).

## Goal

Implement use cases that orchestrate relay control operations. Each use case represents one meaningful user action and coordinates domain logic through the repository interface.

## Scope

- Flutter application layer only.
- Create 5 use case classes following existing patterns.
- Use cases depend on repository interface (testable with mocks).
- No UI logic, no API details.

## Prerequisites

- Task 01 complete: relay entities exist
- Task 02 complete: repository contract defined
- Understanding of existing use case pattern (`device_usecases.dart`)

## Architecture Decision

Follow existing single-responsibility use case pattern:
- One class per use case
- Constructor takes repository
- `call()` method executes the operation
- No state stored in use cases (stateless)
- Errors propagate to caller (provider/UI handles them)

## Relevant Existing Files

- `kvx_flutter/lib/application/usecases/device_usecases.dart` (pattern reference)
- `kvx_flutter/lib/domain/repositories/device_repository.dart` (interface)
- `kvx_flutter/lib/domain/entities/relay_reminder.dart`

## Expected Files

**Create:**
- `kvx_flutter/lib/application/usecases/toggle_relay_usecase.dart`
- `kvx_flutter/lib/application/usecases/activate_relay_for_duration_usecase.dart`
- `kvx_flutter/lib/application/usecases/manage_relay_reminder_usecase.dart`
- `kvx_flutter/lib/application/usecases/get_relay_statistics_usecase.dart`
- `kvx_flutter/lib/application/usecases/control_device_usecase.dart`

**Test:**
- `kvx_flutter/test/application/usecases/toggle_relay_usecase_test.dart`
- `kvx_flutter/test/application/usecases/manage_relay_reminder_usecase_test.dart`
- `kvx_flutter/test/application/usecases/control_device_usecase_test.dart`

## Implementation Details

### 1. ToggleRelayUseCase

```dart
import '../../domain/repositories/device_repository.dart';

class ToggleRelayUseCase {
  final DeviceRepository _repository;

  ToggleRelayUseCase(this._repository);

  Future<void> call({
    required String deviceId,
    required int relayIndex,
    required bool isOn,
  }) {
    return _repository.toggleRelay(
      deviceId: deviceId,
      relayIndex: relayIndex,
      isOn: isOn,
    );
  }
}
```

### 2. ActivateRelayForDurationUseCase

```dart
import '../../domain/repositories/device_repository.dart';

class ActivateRelayForDurationUseCase {
  final DeviceRepository _repository;

  ActivateRelayForDurationUseCase(this._repository);

  Future<void> call({
    required String deviceId,
    required int relayIndex,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) {
      throw ArgumentError('Duration must be positive');
    }
    
    return _repository.activateRelayForDuration(
      deviceId: deviceId,
      relayIndex: relayIndex,
      duration: duration,
    );
  }
}
```

### 3. ManageRelayReminderUseCase

```dart
import '../../domain/entities/relay_reminder.dart';
import '../../domain/repositories/device_repository.dart';

class ManageRelayReminderUseCase {
  final DeviceRepository _repository;

  ManageRelayReminderUseCase(this._repository);

  Future<List<RelayReminder>> getReminders({
    required String deviceId,
    required int relayIndex,
  }) {
    return _repository.getReminders(
      deviceId: deviceId,
      relayIndex: relayIndex,
    );
  }

  Future<RelayReminder> addReminder(RelayReminder reminder) {
    return _repository.addReminder(reminder);
  }

  Future<void> removeReminder(String reminderId) {
    return _repository.removeReminder(reminderId);
  }

  Future<void> toggleReminders({
    required String deviceId,
    required int relayIndex,
    required bool isActive,
  }) {
    return _repository.toggleReminders(
      deviceId: deviceId,
      relayIndex: relayIndex,
      isActive: isActive,
    );
  }
}
```

### 4. GetRelayStatisticsUseCase

```dart
import '../../domain/entities/relay_statistics.dart';
import '../../domain/repositories/device_repository.dart';

class GetRelayStatisticsUseCase {
  final DeviceRepository _repository;

  GetRelayStatisticsUseCase(this._repository);

  Future<RelayStatistics> call({
    required String deviceId,
    required int relayIndex,
  }) {
    return _repository.getRelayStatistics(
      deviceId: deviceId,
      relayIndex: relayIndex,
    );
  }
}
```

### 5. ControlDeviceUseCase

```dart
import '../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';

class ControlDeviceUseCase {
  final DeviceRepository _repository;

  ControlDeviceUseCase(this._repository);

  Future<Device> refresh(String deviceId) {
    return _repository.refreshDevice(deviceId);
  }

  Future<void> restart(String deviceId) {
    return _repository.restartDevice(deviceId);
  }

  Future<void> resetWifi(String deviceId) {
    return _repository.resetWifi(deviceId);
  }
}
```

## Acceptance Criteria

- [ ] All use cases compile without errors
- [ ] Each use case has single responsibility
- [ ] Use cases are stateless (no instance variables except repository)
- [ ] `call()` method used for primary operation (matches existing pattern)
- [ ] Multiple operations grouped logically (e.g., ManageRelayReminderUseCase)
- [ ] Input validation where appropriate (e.g., duration > 0)
- [ ] Clear `ArgumentError` messages for validation failures
- [ ] No UI imports, no HTTP imports, no concrete repository imports
- [ ] Unit tests cover:
  - Happy path execution
  - Validation errors
  - Error propagation from repository
  - All methods in multi-method use cases

## Testing Strategy

### Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([DeviceRepository])
void main() {
  late MockDeviceRepository mockRepository;
  late ToggleRelayUseCase useCase;

  setUp(() {
    mockRepository = MockDeviceRepository();
    useCase = ToggleRelayUseCase(mockRepository);
  });

  group('ToggleRelayUseCase', () {
    test('should call repository with correct parameters', () async {
      // Arrange
      when(mockRepository.toggleRelay(
        deviceId: any,
        relayIndex: any,
        isOn: any,
      )).thenAnswer((_) async => {});

      // Act
      await useCase(
        deviceId: 'device-1',
        relayIndex: 0,
        isOn: true,
      );

      // Assert
      verify(mockRepository.toggleRelay(
        deviceId: 'device-1',
        relayIndex: 0,
        isOn: true,
      )).called(1);
    });

    test('should propagate repository errors', () async {
      // Arrange
      when(mockRepository.toggleRelay(
        deviceId: any,
        relayIndex: any,
        isOn: any,
      )).thenThrow(Exception('Network error'));

      // Act & Assert
      expect(
        () => useCase(
          deviceId: 'device-1',
          relayIndex: 0,
          isOn: true,
        ),
        throwsException,
      );
    });
  });
}
```

### Test Coverage Requirements

- **ToggleRelayUseCase**: Basic pass-through (1-2 tests)
- **ActivateRelayForDurationUseCase**: Validation + happy path (3-4 tests)
- **ManageRelayReminderUseCase**: All 4 methods tested (8-10 tests)
- **GetRelayStatisticsUseCase**: Basic pass-through (1-2 tests)
- **ControlDeviceUseCase**: All 3 methods tested (3-4 tests)

## Verification

Run use case tests:

```bash
cd kvx_flutter
flutter test test/application/usecases/
```

Expected: All tests pass.

## Implementation Notes

### When to Validate

**Validate in use case:**
- Business rules (duration > 0)
- Semantic constraints (relayIndex >= 0)
- Required field presence

**Don't validate in use case:**
- Data format (URL, email) - do at UI or DTO level
- Network reachability - let repository handle
- Authentication - repository responsibility

### Error Handling Pattern

Use cases should:
1. Validate input (throw `ArgumentError` if invalid)
2. Call repository
3. Let repository errors propagate (don't catch/wrap)

Providers will catch and convert to user-friendly messages.

### Grouping Logic

Multi-method use cases are OK when operations are tightly related:
- ✅ `ManageRelayReminderUseCase` - all reminder CRUD in one place
- ✅ `ControlDeviceUseCase` - all device-level commands grouped
- ❌ Don't group unrelated operations

## Risks / Limitations

- **Risk**: Validation logic might duplicate between use case and entity
  - **Mitigation**: Put validation in entity constructor where possible, use case adds context-specific checks

- **Risk**: Too many use case files (maintenance overhead)
  - **Mitigation**: Group related operations (reminder management, device control)

- **Limitation**: No transaction support (e.g., toggle multiple relays atomically)
  - **Rationale**: Backend doesn't support transactions, keep use cases simple

## Out of Scope

- Provider implementation (Task 09)
- Repository implementation (Tasks 05, 06)
- UI integration (Tasks 10-12)
- Retry logic (add later if needed)
- Undo/redo functionality
- Offline queueing

## Follow-Up Tasks

After completion:
- Task 06: Implement repository (use cases will call it)
- Task 09: Implement provider (will inject these use cases)
- Integration test: Provider → Use Case → Mock Repository
