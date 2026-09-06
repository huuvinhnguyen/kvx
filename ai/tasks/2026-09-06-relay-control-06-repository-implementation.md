# Task 06 — Relay Control Repository Implementation

## Status

Ready to start (depends on Tasks 04, 05).

## Goal

Implement the repository layer that connects data sources to domain logic. Repository orchestrates datasource calls, maps DTOs to domain entities, and handles errors.

## Scope

- Flutter data layer only.
- Extend `DeviceRepositoryImpl` with relay control methods.
- Map DTOs to domain entities.
- Delegate to datasource (in-memory or BinBlog).
- Handle errors and convert to domain exceptions.

## Prerequisites

- Task 02 complete: repository interface defined
- Task 04 complete: DTOs exist for mapping
- Task 05A or 05B complete: at least one datasource implemented
- Understanding of existing `DeviceRepositoryImpl`

## Architecture Decision

Extend existing `DeviceRepositoryImpl` because:
- Repository already manages device data
- Keeps device operations centralized
- Single point for datasource injection
- Matches established pattern

Repository responsibilities:
- Delegate to datasource
- Map DTO → Domain
- Handle errors (convert exceptions)
- No business logic (that's in use cases)

## Relevant Existing Files

- `kvx_flutter/lib/data/repositories/device_repository_impl.dart`
- `kvx_flutter/lib/domain/repositories/device_repository.dart` (interface)
- `kvx_flutter/lib/data/models/binblog_relay_reminder_dto.dart`
- `kvx_flutter/lib/data/datasources/device_local_datasource.dart`

## Expected Files

**Modify:**
- `kvx_flutter/lib/data/repositories/device_repository_impl.dart`

**Test:**
- `kvx_flutter/test/data/repositories/device_repository_impl_test.dart` (extend existing)

## Implementation Details

### Extend DeviceRepositoryImpl

```dart
// device_repository_impl.dart

import '../../domain/entities/device.dart';
import '../../domain/entities/relay_reminder.dart';
import '../../domain/entities/relay_statistics.dart';
import '../../domain/repositories/device_repository.dart';
import '../datasources/device_local_datasource.dart';
import '../models/binblog_relay_reminder_dto.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final DeviceDataSource _dataSource;
  List<Device> _devices = [];

  DeviceRepositoryImpl(this._dataSource);

  // ... existing methods (getDevices, addDevice, etc.) ...

  @override
  Future<void> toggleRelay({
    required String deviceId,
    required int relayIndex,
    required bool isOn,
  }) async {
    try {
      await _dataSource.toggleRelay(
        deviceId: deviceId,
        relayIndex: relayIndex,
        isOn: isOn,
      );
    } catch (e) {
      throw _handleError(e, 'toggle relay');
    }
  }

  @override
  Future<void> activateRelayForDuration({
    required String deviceId,
    required int relayIndex,
    required Duration duration,
  }) async {
    try {
      await _dataSource.activateRelayForDuration(
        deviceId: deviceId,
        relayIndex: relayIndex,
        duration: duration,
      );
    } catch (e) {
      throw _handleError(e, 'activate relay');
    }
  }

  @override
  Future<List<RelayReminder>> getReminders({
    required String deviceId,
    required int relayIndex,
  }) async {
    try {
      final dtos = await _dataSource.getReminders(
        deviceId: deviceId,
        relayIndex: relayIndex,
      );
      return dtos.map((dto) => dto.toDomain()).toList();
    } catch (e) {
      throw _handleError(e, 'get reminders');
    }
  }

  @override
  Future<RelayReminder> addReminder(RelayReminder reminder) async {
    try {
      final dto = BinblogRelayReminderDto.fromDomain(reminder);
      final resultDto = await _dataSource.addReminder(dto);
      return resultDto.toDomain();
    } catch (e) {
      throw _handleError(e, 'add reminder');
    }
  }

  @override
  Future<void> removeReminder(String reminderId) async {
    try {
      await _dataSource.removeReminder(reminderId);
    } catch (e) {
      throw _handleError(e, 'remove reminder');
    }
  }

  @override
  Future<void> toggleReminders({
    required String deviceId,
    required int relayIndex,
    required bool isActive,
  }) async {
    try {
      await _dataSource.toggleReminders(
        deviceId: deviceId,
        relayIndex: relayIndex,
        isActive: isActive,
      );
    } catch (e) {
      throw _handleError(e, 'toggle reminders');
    }
  }

  @override
  Future<RelayStatistics> getRelayStatistics({
    required String deviceId,
    required int relayIndex,
  }) async {
    try {
      final dto = await _dataSource.getRelayStatistics(
        deviceId: deviceId,
        relayIndex: relayIndex,
      );
      return dto.toDomain();
    } catch (e) {
      throw _handleError(e, 'get statistics');
    }
  }

  @override
  Future<Device> refreshDevice(String deviceId) async {
    try {
      final data = await _dataSource.refreshDevice(deviceId);
      
      // Find existing device and update it
      final deviceIndex = _devices.indexWhere((d) => d.id == deviceId);
      if (deviceIndex == -1) {
        throw DeviceNotFoundException('Device $deviceId not found');
      }
      
      final existingDevice = _devices[deviceIndex];
      
      // Update device with fresh data from API
      final updatedDevice = existingDevice.copyWith(
        lastConnected: data['last_connected'] != null
            ? DateTime.parse(data['last_connected'] as String)
            : null,
        // Update relay states if present
        // relayChannels: ... (parse from data if available)
      );
      
      _devices[deviceIndex] = updatedDevice;
      return updatedDevice;
    } catch (e) {
      throw _handleError(e, 'refresh device');
    }
  }

  @override
  Future<void> restartDevice(String deviceId) async {
    try {
      await _dataSource.restartDevice(deviceId);
    } catch (e) {
      throw _handleError(e, 'restart device');
    }
  }

  @override
  Future<void> resetWifi(String deviceId) async {
    try {
      await _dataSource.resetWifi(deviceId);
    } catch (e) {
      throw _handleError(e, 'reset wifi');
    }
  }

  // Error handling helper
  Exception _handleError(Object error, String operation) {
    // Convert datasource exceptions to domain exceptions
    if (error is FormatException) {
      return DataFormatException(
        'Dữ liệu không hợp lệ khi $operation: ${error.message}',
      );
    }
    
    // Keep other exceptions as-is (BinblogApiException, etc.)
    if (error is Exception) {
      return error;
    }
    
    // Wrap unknown errors
    return RepositoryException(
      'Lỗi không xác định khi $operation: $error',
    );
  }
}

// Domain exceptions
class DeviceNotFoundException implements Exception {
  final String message;
  DeviceNotFoundException(this.message);
  
  @override
  String toString() => message;
}

class DataFormatException implements Exception {
  final String message;
  DataFormatException(this.message);
  
  @override
  String toString() => message;
}

class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);
  
  @override
  String toString() => message;
}
```

## Acceptance Criteria

- [ ] All repository methods implemented
- [ ] DTOs mapped to domain entities correctly
- [ ] Errors from datasource caught and wrapped
- [ ] Domain exceptions have clear Vietnamese messages
- [ ] `refreshDevice` updates cached device state
- [ ] Repository is stateless except for device cache
- [ ] No direct HTTP calls (delegates to datasource)
- [ ] Unit tests cover:
  - Successful DTO → Domain mapping
  - Error propagation from datasource
  - `refreshDevice` updates device list
  - All relay methods delegate correctly

## Testing Strategy

### Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([DeviceDataSource])
void main() {
  late MockDeviceDataSource mockDataSource;
  late DeviceRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockDeviceDataSource();
    repository = DeviceRepositoryImpl(mockDataSource);
  });

  group('toggleRelay', () {
    test('should delegate to datasource', () async {
      // Arrange
      when(mockDataSource.toggleRelay(
        deviceId: any,
        relayIndex: any,
        isOn: any,
      )).thenAnswer((_) async => {});

      // Act
      await repository.toggleRelay(
        deviceId: 'device-1',
        relayIndex: 0,
        isOn: true,
      );

      // Assert
      verify(mockDataSource.toggleRelay(
        deviceId: 'device-1',
        relayIndex: 0,
        isOn: true,
      )).called(1);
    });

    test('should propagate datasource errors', () async {
      // Arrange
      when(mockDataSource.toggleRelay(
        deviceId: any,
        relayIndex: any,
        isOn: any,
      )).thenThrow(Exception('Network error'));

      // Act & Assert
      expect(
        () => repository.toggleRelay(
          deviceId: 'device-1',
          relayIndex: 0,
          isOn: true,
        ),
        throwsException,
      );
    });
  });

  group('getReminders', () {
    test('should map DTOs to domain entities', () async {
      // Arrange
      final dto = BinblogRelayReminderDto(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: '2026-09-06T08:00:00Z',
        duration: 300000,
        repeatType: 'daily',
        isActive: true,
      );
      
      when(mockDataSource.getReminders(
        deviceId: any,
        relayIndex: any,
      )).thenAnswer((_) async => [dto]);

      // Act
      final result = await repository.getReminders(
        deviceId: 'device-1',
        relayIndex: 0,
      );

      // Assert
      expect(result, isA<List<RelayReminder>>());
      expect(result.length, 1);
      expect(result[0].id, 'reminder-1');
      expect(result[0].deviceId, 'device-1');
      expect(result[0].duration, const Duration(milliseconds: 300000));
    });

    test('should wrap format exceptions', () async {
      // Arrange
      final invalidDto = BinblogRelayReminderDto(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: 'invalid-date',
        duration: 300000,
        repeatType: 'daily',
        isActive: true,
      );
      
      when(mockDataSource.getReminders(
        deviceId: any,
        relayIndex: any,
      )).thenAnswer((_) async => [invalidDto]);

      // Act & Assert
      expect(
        () => repository.getReminders(
          deviceId: 'device-1',
          relayIndex: 0,
        ),
        throwsA(isA<DataFormatException>()),
      );
    });
  });

  group('addReminder', () {
    test('should convert domain to DTO and back', () async {
      // Arrange
      final reminder = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: DateTime.parse('2026-09-06T08:00:00Z'),
        duration: const Duration(minutes: 5),
        repeatType: ReminderRepeatType.daily,
        isActive: true,
      );
      
      final dto = BinblogRelayReminderDto.fromDomain(reminder);
      
      when(mockDataSource.addReminder(any))
          .thenAnswer((_) async => dto);

      // Act
      final result = await repository.addReminder(reminder);

      // Assert
      expect(result.id, reminder.id);
      expect(result.deviceId, reminder.deviceId);
      expect(result.duration, reminder.duration);
      verify(mockDataSource.addReminder(any)).called(1);
    });
  });

  group('refreshDevice', () {
    test('should update device in cache', () async {
      // Arrange
      final device = Device(
        id: 'device-1',
        name: 'Test Device',
        type: DeviceType.switchDevice,
        status: DeviceStatus.online,
      );
      
      repository._devices = [device];
      
      when(mockDataSource.refreshDevice(any))
          .thenAnswer((_) async => {
                'device_id': 'device-1',
                'last_connected': '2026-09-06T10:00:00Z',
              });

      // Act
      final result = await repository.refreshDevice('device-1');

      // Assert
      expect(result.id, 'device-1');
      expect(result.lastConnected, isNotNull);
      verify(mockDataSource.refreshDevice('device-1')).called(1);
    });

    test('should throw if device not found', () async {
      // Arrange
      repository._devices = [];
      
      when(mockDataSource.refreshDevice(any))
          .thenAnswer((_) async => {});

      // Act & Assert
      expect(
        () => repository.refreshDevice('device-1'),
        throwsA(isA<DeviceNotFoundException>()),
      );
    });
  });
}
```

### Test Coverage

- **toggleRelay**: Delegation + error handling (2 tests)
- **activateRelayForDuration**: Delegation + error handling (2 tests)
- **getReminders**: DTO mapping + format errors (3 tests)
- **addReminder**: Domain → DTO → Domain roundtrip (2 tests)
- **removeReminder**: Delegation + error handling (2 tests)
- **toggleReminders**: Delegation + error handling (2 tests)
- **getRelayStatistics**: DTO mapping (2 tests)
- **refreshDevice**: Device cache update + not found (3 tests)
- **restartDevice**: Delegation (1 test)
- **resetWifi**: Delegation (1 test)

**Total**: ~20 tests

## Verification

Run repository tests:

```bash
cd kvx_flutter
flutter test test/data/repositories/device_repository_impl_test.dart
```

Expected: All tests pass, no compilation errors.

## Implementation Notes

### DTO Mapping Pattern

```dart
// Get operations: DTO → Domain
final dtos = await _dataSource.getReminders(...);
return dtos.map((dto) => dto.toDomain()).toList();

// Create operations: Domain → DTO → API → DTO → Domain
final dto = BinblogRelayReminderDto.fromDomain(reminder);
final resultDto = await _dataSource.addReminder(dto);
return resultDto.toDomain();
```

### Error Handling Strategy

**Don't catch:**
- Business logic errors (let use cases handle)
- Authentication errors (let datasource exception propagate)

**Do catch:**
- Format exceptions (invalid DTO mapping)
- Unknown errors (wrap with context)

**Don't:**
- Log sensitive data
- Show stack traces to users
- Retry here (provider handles retry)

### State Management

Repository maintains device cache:
- `_devices` list updated by `refreshDevice`
- Used to find and update devices
- Not thread-safe (single-threaded Dart isolate)

### RefreshDevice Logic

```dart
1. Call datasource.refreshDevice(deviceId)
2. Get updated data (last_connected, relay_states, etc.)
3. Find device in cache
4. Update device with new data
5. Return updated device
```

## Risks / Limitations

- **Risk**: DTO mapping throws unexpected exceptions
  - **Mitigation**: Comprehensive DTO tests catch issues early

- **Risk**: Device cache gets stale
  - **Mitigation**: Provider calls refreshDevice when needed

- **Risk**: Concurrent calls to same device
  - **Mitigation**: Not a problem in single-threaded Dart

- **Limitation**: No request deduplication (multiple simultaneous calls to same endpoint)
  - **Rationale**: Provider manages state, shouldn't trigger duplicate calls

## Out of Scope

- Request caching (beyond device list)
- Request deduplication
- Retry logic
- Offline queue
- WebSocket integration
- Pagination

## Follow-Up Tasks

After completion:
- Task 03: Use cases call this repository (already done if in parallel)
- Task 09: Provider uses repository via use cases
- Integration test: Provider → Use Case → Repository → Mock Datasource
- Manual test: Full stack with real API
