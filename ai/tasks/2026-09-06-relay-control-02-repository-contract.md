# Task 02 — Relay Control Repository Contract

## Status

Ready to start (depends on Task 01).

## Goal

Define repository interface for relay control operations. This contract will be implemented by data layer adapters (in-memory, BinBlog API) without coupling domain logic to concrete implementations.

## Scope

- Flutter domain layer only.
- Extend `DeviceRepository` interface with relay-specific methods.
- Define method signatures, parameters, and return types.
- No implementation, just the contract.

## Prerequisites

- Task 01 complete: relay domain entities exist
- Current `DeviceRepository` interface understood

## Architecture Decision

Extend existing `DeviceRepository` rather than creating a separate `RelayRepository` because:
- Relay control is device-specific (requires deviceId)
- Keeps device operations centralized
- Avoids splitting device management across multiple repositories
- Matches existing pattern (device CRUD in one place)

## Relevant Existing Files

- `kvx_flutter/lib/domain/repositories/device_repository.dart`
- `kvx_flutter/lib/domain/entities/relay_reminder.dart` (from Task 01)
- `kvx_flutter/lib/domain/entities/relay_statistics.dart` (from Task 01)

## Expected Files

**Modify:**
- `kvx_flutter/lib/domain/repositories/device_repository.dart`

## Implementation Details

Extend `DeviceRepository` with these methods:

### Relay Control

```dart
// Toggle relay on/off
Future<void> toggleRelay({
  required String deviceId,
  required int relayIndex,
  required bool isOn,
});

// Activate relay for a specific duration, then auto-off
Future<void> activateRelayForDuration({
  required String deviceId,
  required int relayIndex,
  required Duration duration,
});
```

### Reminder Management

```dart
// Get all reminders for a specific relay channel
Future<List<RelayReminder>> getReminders({
  required String deviceId,
  required int relayIndex,
});

// Add a new reminder
Future<RelayReminder> addReminder(RelayReminder reminder);

// Remove a reminder by ID
Future<void> removeReminder(String reminderId);

// Enable/disable all reminders for a channel
Future<void> toggleReminders({
  required String deviceId,
  required int relayIndex,
  required bool isActive,
});
```

### Statistics

```dart
// Get usage statistics for a relay channel
Future<RelayStatistics> getRelayStatistics({
  required String deviceId,
  required int relayIndex,
});
```

### Device Control

```dart
// Refresh device state from server
Future<Device> refreshDevice(String deviceId);

// Restart device (reboot)
Future<void> restartDevice(String deviceId);

// Reset WiFi configuration (device enters AP mode)
Future<void> resetWifi(String deviceId);
```

## Full Interface

```dart
import '../entities/device.dart';
import '../entities/relay_reminder.dart';
import '../entities/relay_statistics.dart';

abstract class DeviceRepository {
  // Existing methods
  Future<List<Device>> getDevices();
  Future<void> addDevice(Device device);
  Future<void> updateDevice(Device device);
  Future<void> deleteDevice(String id);
  
  // Relay control
  Future<void> toggleRelay({
    required String deviceId,
    required int relayIndex,
    required bool isOn,
  });
  
  Future<void> activateRelayForDuration({
    required String deviceId,
    required int relayIndex,
    required Duration duration,
  });
  
  // Reminder management
  Future<List<RelayReminder>> getReminders({
    required String deviceId,
    required int relayIndex,
  });
  
  Future<RelayReminder> addReminder(RelayReminder reminder);
  
  Future<void> removeReminder(String reminderId);
  
  Future<void> toggleReminders({
    required String deviceId,
    required int relayIndex,
    required bool isActive,
  });
  
  // Statistics
  Future<RelayStatistics> getRelayStatistics({
    required String deviceId,
    required int relayIndex,
  });
  
  // Device control
  Future<Device> refreshDevice(String deviceId);
  
  Future<void> restartDevice(String deviceId);
  
  Future<void> resetWifi(String deviceId);
}
```

## Acceptance Criteria

- [ ] Interface compiles without errors
- [ ] All method signatures use named parameters for clarity
- [ ] Return types are explicit (no dynamic)
- [ ] Methods throw exceptions on failure (document in comments)
- [ ] No concrete implementation in this file
- [ ] Import statements only reference domain entities
- [ ] Method names are clear and self-documenting
- [ ] Parameters match entity field types exactly

## Error Handling Strategy

Document expected exceptions (in method comments):

- **Network errors**: Implementations should throw descriptive exceptions
- **Device not found**: Throw or return null (decide per method)
- **Invalid parameters**: Let Dart's type system catch at compile time
- **Authentication failures**: Throw with clear message
- **Timeout**: Throw with timeout context

Example comment:
```dart
/// Throws [DeviceNotFoundException] if device doesn't exist.
/// Throws [NetworkException] on connection failure.
/// Throws [AuthenticationException] if credentials invalid.
Future<void> toggleRelay({...});
```

## Verification

Check compilation:

```bash
cd kvx_flutter
flutter analyze lib/domain/
```

Expected: No errors, no warnings.

## Implementation Notes

- Use named parameters for methods with 3+ params (readability)
- `deviceId` is always a String (stable identifier from backend)
- `relayIndex` is 0-based integer
- `Duration` is Dart's built-in type (no custom duration type)
- `Future<void>` for fire-and-forget operations
- `Future<T>` when result is needed (e.g., `addReminder` returns created reminder with ID)
- Don't add timeout parameters to interface (implementations handle that internally)

## Risks / Limitations

- **Risk**: Backend API might not support all operations
  - **Mitigation**: Interface defines ideal contract; implementations can throw `UnsupportedError` if needed
  
- **Risk**: Method signatures might need adjustment after real API testing
  - **Mitigation**: Keep interface flexible, add optional parameters if needed later

- **Limitation**: No batch operations (e.g., toggle multiple relays at once)
  - **Rationale**: YAGNI - add when needed

## Out of Scope

- Repository implementation (Tasks 05, 06)
- Use cases that call these methods (Task 03)
- DTO models (Task 04)
- Error handling implementation
- Retry logic
- Caching strategy

## Follow-Up Tasks

After completion:
- Task 03: Implement use cases that call this repository
- Task 05A: Implement in-memory datasource (for testing)
- Task 05B: Implement BinBlog API datasource
- Task 06: Implement repository with one of the datasources
