# Task 04 — Relay Control DTOs and Mapping

## Status

Ready to start (depends on Task 01).

## Goal

Create Data Transfer Objects (DTOs) for mapping API responses to domain entities. DTOs handle JSON serialization, API-specific field names, and type conversions.

## Scope

- Flutter data layer only.
- Create 3 DTO models for relay API responses.
- Implement `fromJson`, `toJson`, and `toDomain` methods.
- Handle null/missing fields gracefully.
- No API calls in this task, just data mapping.

## Prerequisites

- Task 01 complete: relay domain entities exist
- Understanding of existing DTO pattern (`binblog_device_dto.dart`)
- API contract understood (from architecture doc)

## Architecture Decision

DTOs sit between API and domain:
- API returns snake_case JSON with possible nulls
- DTOs parse JSON with type safety
- DTOs convert to domain entities with validation
- Keep DTOs dumb: no business logic, just data transformation

## Relevant Existing Files

- `kvx_flutter/lib/data/models/binblog_device_dto.dart` (pattern reference)
- `kvx_flutter/lib/domain/entities/relay_reminder.dart`
- `kvx_flutter/lib/domain/entities/relay_statistics.dart`
- `docs/architecture/relay-control-detail-screen.md` (API contract)

## Expected Files

**Create:**
- `kvx_flutter/lib/data/models/binblog_relay_channel_dto.dart`
- `kvx_flutter/lib/data/models/binblog_relay_reminder_dto.dart`
- `kvx_flutter/lib/data/models/binblog_relay_statistics_dto.dart`

**Test:**
- `kvx_flutter/test/data/models/binblog_relay_channel_dto_test.dart`
- `kvx_flutter/test/data/models/binblog_relay_reminder_dto_test.dart`
- `kvx_flutter/test/data/models/binblog_relay_statistics_dto_test.dart`

## Implementation Details

### 1. BinblogRelayChannelDto

```dart
import '../../domain/entities/relay_channel.dart';

class BinblogRelayChannelDto {
  final int index;
  final bool isOn;
  final String? label;

  const BinblogRelayChannelDto({
    required this.index,
    required this.isOn,
    this.label,
  });

  factory BinblogRelayChannelDto.fromJson(Map<String, dynamic> json) {
    return BinblogRelayChannelDto(
      index: json['index'] as int,
      isOn: json['is_on'] as bool,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'is_on': isOn,
      if (label != null) 'label': label,
    };
  }

  RelayChannel toDomain() {
    return RelayChannel(
      index: index,
      isOn: isOn,
      label: label,
    );
  }
}
```

### 2. BinblogRelayReminderDto

**API Contract** (from architecture doc):
```json
{
  "id": "reminder-123",
  "device_id": "esp8266_11729385",
  "relay_index": 0,
  "start_time": "2026-09-06T08:00:00Z",
  "duration": 300000,
  "repeat_type": "daily",
  "is_active": true
}
```

```dart
import '../../domain/entities/relay_reminder.dart';
import '../../domain/entities/reminder_repeat_type.dart';

class BinblogRelayReminderDto {
  final String id;
  final String deviceId;
  final int relayIndex;
  final String startTime;      // ISO 8601 string
  final int duration;           // milliseconds
  final String repeatType;      // "none", "daily", "weekly", "monthly"
  final bool isActive;

  const BinblogRelayReminderDto({
    required this.id,
    required this.deviceId,
    required this.relayIndex,
    required this.startTime,
    required this.duration,
    required this.repeatType,
    required this.isActive,
  });

  factory BinblogRelayReminderDto.fromJson(Map<String, dynamic> json) {
    return BinblogRelayReminderDto(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      relayIndex: json['relay_index'] as int,
      startTime: json['start_time'] as String,
      duration: json['duration'] as int,
      repeatType: json['repeat_type'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'relay_index': relayIndex,
      'start_time': startTime,
      'duration': duration,
      'repeat_type': repeatType,
      'is_active': isActive,
    };
  }

  RelayReminder toDomain() {
    // Parse ISO 8601 datetime
    final parsedStartTime = DateTime.parse(startTime);
    
    // Convert milliseconds to Duration
    final parsedDuration = Duration(milliseconds: duration);
    
    // Map string to enum
    final parsedRepeatType = _parseRepeatType(repeatType);
    
    return RelayReminder(
      id: id,
      deviceId: deviceId,
      relayIndex: relayIndex,
      startTime: parsedStartTime,
      duration: parsedDuration,
      repeatType: parsedRepeatType,
      isActive: isActive,
    );
  }

  static ReminderRepeatType _parseRepeatType(String value) {
    return switch (value.toLowerCase()) {
      'none' => ReminderRepeatType.none,
      'daily' => ReminderRepeatType.daily,
      'weekly' => ReminderRepeatType.weekly,
      'monthly' => ReminderRepeatType.monthly,
      _ => throw FormatException('Unknown repeat type: $value'),
    };
  }

  factory BinblogRelayReminderDto.fromDomain(RelayReminder reminder) {
    return BinblogRelayReminderDto(
      id: reminder.id,
      deviceId: reminder.deviceId,
      relayIndex: reminder.relayIndex,
      startTime: reminder.startTime.toIso8601String(),
      duration: reminder.duration.inMilliseconds,
      repeatType: _repeatTypeToString(reminder.repeatType),
      isActive: reminder.isActive,
    );
  }

  static String _repeatTypeToString(ReminderRepeatType type) {
    return switch (type) {
      ReminderRepeatType.none => 'none',
      ReminderRepeatType.daily => 'daily',
      ReminderRepeatType.weekly => 'weekly',
      ReminderRepeatType.monthly => 'monthly',
    };
  }
}
```

### 3. BinblogRelayStatisticsDto

```dart
import '../../domain/entities/relay_statistics.dart';

class BinblogRelayStatisticsDto {
  final String deviceId;
  final int relayIndex;
  final int totalOnTimeMs;       // milliseconds
  final int activationCount;
  final String? lastActivated;   // ISO 8601 string, nullable

  const BinblogRelayStatisticsDto({
    required this.deviceId,
    required this.relayIndex,
    required this.totalOnTimeMs,
    required this.activationCount,
    this.lastActivated,
  });

  factory BinblogRelayStatisticsDto.fromJson(Map<String, dynamic> json) {
    return BinblogRelayStatisticsDto(
      deviceId: json['device_id'] as String,
      relayIndex: json['relay_index'] as int,
      totalOnTimeMs: json['total_on_time_ms'] as int,
      activationCount: json['activation_count'] as int,
      lastActivated: json['last_activated'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'relay_index': relayIndex,
      'total_on_time_ms': totalOnTimeMs,
      'activation_count': activationCount,
      if (lastActivated != null) 'last_activated': lastActivated,
    };
  }

  RelayStatistics toDomain() {
    return RelayStatistics(
      deviceId: deviceId,
      relayIndex: relayIndex,
      totalOnTime: Duration(milliseconds: totalOnTimeMs),
      activationCount: activationCount,
      lastActivated: lastActivated != null 
          ? DateTime.parse(lastActivated!)
          : null,
    );
  }
}
```

## Acceptance Criteria

- [ ] All DTOs compile without errors
- [ ] `fromJson` handles valid JSON correctly
- [ ] `toJson` produces valid JSON for API requests
- [ ] `toDomain` converts to domain entities correctly
- [ ] `fromDomain` implemented for request payloads (where needed)
- [ ] Null safety handled (nullable fields don't crash)
- [ ] DateTime parsing uses `DateTime.parse()` (handles ISO 8601)
- [ ] Duration conversion handles milliseconds correctly
- [ ] Enum mapping handles all cases + unknown values
- [ ] Tests cover:
  - Valid JSON → DTO → Domain
  - Missing optional fields
  - Invalid datetime format (throws)
  - Invalid repeat type (throws)
  - Null last_activated (allowed)
  - Round-trip: Domain → DTO → JSON → DTO → Domain

## Testing Strategy

### Example Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/data/models/binblog_relay_reminder_dto.dart';
import 'package:kvx_flutter/domain/entities/reminder_repeat_type.dart';

void main() {
  group('BinblogRelayReminderDto', () {
    test('fromJson creates DTO from valid JSON', () {
      // Arrange
      final json = {
        'id': 'reminder-1',
        'device_id': 'device-1',
        'relay_index': 0,
        'start_time': '2026-09-06T08:00:00Z',
        'duration': 300000,
        'repeat_type': 'daily',
        'is_active': true,
      };

      // Act
      final dto = BinblogRelayReminderDto.fromJson(json);

      // Assert
      expect(dto.id, 'reminder-1');
      expect(dto.deviceId, 'device-1');
      expect(dto.relayIndex, 0);
      expect(dto.duration, 300000);
      expect(dto.repeatType, 'daily');
      expect(dto.isActive, true);
    });

    test('toDomain converts DTO to domain entity', () {
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

      // Act
      final domain = dto.toDomain();

      // Assert
      expect(domain.id, 'reminder-1');
      expect(domain.deviceId, 'device-1');
      expect(domain.relayIndex, 0);
      expect(domain.duration, const Duration(milliseconds: 300000));
      expect(domain.repeatType, ReminderRepeatType.daily);
      expect(domain.isActive, true);
      expect(domain.startTime, DateTime.parse('2026-09-06T08:00:00Z'));
    });

    test('fromJson defaults is_active to true when missing', () {
      // Arrange
      final json = {
        'id': 'reminder-1',
        'device_id': 'device-1',
        'relay_index': 0,
        'start_time': '2026-09-06T08:00:00Z',
        'duration': 300000,
        'repeat_type': 'daily',
        // is_active missing
      };

      // Act
      final dto = BinblogRelayReminderDto.fromJson(json);

      // Assert
      expect(dto.isActive, true);
    });

    test('toDomain throws on invalid datetime format', () {
      // Arrange
      final dto = BinblogRelayReminderDto(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: 'invalid-datetime',
        duration: 300000,
        repeatType: 'daily',
        isActive: true,
      );

      // Act & Assert
      expect(() => dto.toDomain(), throwsFormatException);
    });

    test('toDomain throws on unknown repeat type', () {
      // Arrange
      final dto = BinblogRelayReminderDto(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: '2026-09-06T08:00:00Z',
        duration: 300000,
        repeatType: 'unknown',
        isActive: true,
      );

      // Act & Assert
      expect(() => dto.toDomain(), throwsFormatException);
    });

    test('round-trip conversion preserves data', () {
      // Arrange
      final original = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: DateTime.parse('2026-09-06T08:00:00Z'),
        duration: const Duration(minutes: 5),
        repeatType: ReminderRepeatType.daily,
        isActive: true,
      );

      // Act
      final dto = BinblogRelayReminderDto.fromDomain(original);
      final json = dto.toJson();
      final parsedDto = BinblogRelayReminderDto.fromJson(json);
      final result = parsedDto.toDomain();

      // Assert
      expect(result.id, original.id);
      expect(result.deviceId, original.deviceId);
      expect(result.relayIndex, original.relayIndex);
      expect(result.startTime, original.startTime);
      expect(result.duration, original.duration);
      expect(result.repeatType, original.repeatType);
      expect(result.isActive, original.isActive);
    });
  });
}
```

## Verification

Run DTO tests:

```bash
cd kvx_flutter
flutter test test/data/models/
```

Expected: All tests pass, edge cases handled.

## Implementation Notes

### DateTime Handling

- **API sends/receives**: ISO 8601 strings (`"2026-09-06T08:00:00Z"`)
- **Domain uses**: `DateTime` objects
- **Conversion**: `DateTime.parse()` and `DateTime.toIso8601String()`
- **Timezone**: Store UTC in domain, convert to local in UI

### Duration Handling

- **API sends/receives**: Integer milliseconds
- **Domain uses**: `Duration` objects
- **Conversion**: `Duration(milliseconds: value)` and `duration.inMilliseconds`

### Enum Mapping

- **API sends/receives**: Lowercase strings (`"daily"`, `"weekly"`)
- **Domain uses**: `ReminderRepeatType` enum
- **Conversion**: Manual switch/case with error handling
- **Unknown values**: Throw `FormatException` with clear message

### Null Handling

- **Optional fields**: Use `?` and null checks
- **Default values**: Use `??` operator (e.g., `isActive ?? true`)
- **Required fields**: Let cast fail with clear error

## Risks / Limitations

- **Risk**: API contract differs from documented spec
  - **Mitigation**: Comprehensive tests + early integration testing with real API
  
- **Risk**: Timezone bugs (datetime interpreted as local instead of UTC)
  - **Mitigation**: Always use UTC in API, document this clearly

- **Risk**: Integer overflow for large durations
  - **Mitigation**: Use `int` (64-bit in Dart), reasonable limits in validation

- **Limitation**: No schema validation (rely on backend to send correct types)
  - **Rationale**: Keep DTOs simple, let cast failures surface quickly

## Out of Scope

- API client implementation (Task 05B)
- Repository implementation (Task 06)
- Request body validation
- Response pagination
- Error response DTOs (handle as exceptions)

## Follow-Up Tasks

After completion:
- Task 05B: Use these DTOs in BinBlog datasource
- Task 06: Repository maps DTO → Domain via `toDomain()`
- Integration test: Real API → DTO → Domain
