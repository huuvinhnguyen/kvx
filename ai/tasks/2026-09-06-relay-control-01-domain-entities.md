# Task 01 — Relay Control Domain Entities

## Status

Ready to start.

## Goal

Create relay-specific domain entities that represent relay channels, reminders, and statistics in a framework-independent way.

## Scope

- **Both Swift and Flutter** domain layers.
- Define `RelayChannel`, `RelayReminder`, `ReminderRepeatType`, and `RelayStatistics` entities.
- Extend `Device` entity with relay-specific fields.
- No UI, no API calls, pure business logic.
- Keep Swift and Flutter implementations architecturally aligned.

## Prerequisites

- Architecture decision document completed: `docs/architecture/relay-control-detail-screen.md`
- Current `Device` entity understood

## Architecture Decision

Relay control requires separate entities rather than overloading `Device` with channel-specific state, reminder logic, and statistics. This keeps domain models focused and testable.

Key decisions:
- `RelayChannel` represents one controllable relay (index, state, label)
- `RelayReminder` is a scheduled activation with repeat patterns
- `ReminderRepeatType` enum defines schedule patterns (none, daily, weekly, monthly)
- `RelayStatistics` tracks usage metrics per channel
- `Device` extended with optional relay fields (null for non-relay devices)

## Relevant Existing Files

**Flutter:**
- `kvx_flutter/lib/domain/entities/device.dart`
- `kvx_flutter/lib/domain/entities/schedule.dart` (reference for pattern)

**Swift:**
- `kvx/Models/Device.swift`
- `kvx/Domain/Schedule.swift` (reference for pattern)

**Architecture:**
- `ai/ARCHITECTURE.md`

## Expected Files

### Flutter

**Create:**
- `kvx_flutter/lib/domain/entities/relay_channel.dart`
- `kvx_flutter/lib/domain/entities/reminder_repeat_type.dart`
- `kvx_flutter/lib/domain/entities/relay_reminder.dart`
- `kvx_flutter/lib/domain/entities/relay_statistics.dart`

**Modify:**
- `kvx_flutter/lib/domain/entities/device.dart` (add relay fields)

**Test:**
- `kvx_flutter/test/domain/entities/relay_channel_test.dart`
- `kvx_flutter/test/domain/entities/relay_reminder_test.dart`
- `kvx_flutter/test/domain/entities/relay_statistics_test.dart`

### Swift

**Create:**
- `kvx/Models/RelayChannel.swift`
- `kvx/Models/ReminderRepeatType.swift`
- `kvx/Models/RelayReminder.swift`
- `kvx/Models/RelayStatistics.swift`

**Modify:**
- `kvx/Models/Device.swift` (add relay fields)

**Test:**
- `kvxTests/Models/RelayChannelTests.swift`
- `kvxTests/Models/RelayReminderTests.swift`
- `kvxTests/Models/RelayStatisticsTests.swift`

## Implementation Details

### Flutter Implementation

#### RelayChannel

```dart
class RelayChannel {
  final int index;        // 0, 1, 2, ... (channel number)
  final bool isOn;        // current state
  final String? label;    // optional: "Máy bơm", "Đèn"
  
  const RelayChannel({
    required this.index,
    required this.isOn,
    this.label,
  });
  
  RelayChannel copyWith({
    int? index,
    bool? isOn,
    String? label,
  }) {
    return RelayChannel(
      index: index ?? this.index,
      isOn: isOn ?? this.isOn,
      label: label ?? this.label,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayChannel &&
          runtimeType == other.runtimeType &&
          index == other.index;
  
  @override
  int get hashCode => index.hashCode;
}
```

#### ReminderRepeatType

```dart
enum ReminderRepeatType {
  none('Không lặp lại'),
  daily('Hằng ngày'),
  weekly('Hằng tuần'),
  monthly('Hằng tháng');
  
  final String displayName;
  const ReminderRepeatType(this.displayName);
}
```

#### RelayReminder

```dart
class RelayReminder {
  final String id;
  final String deviceId;
  final int relayIndex;
  final DateTime startTime;
  final Duration duration;      // how long to keep relay on
  final ReminderRepeatType repeatType;
  final bool isActive;
  
  const RelayReminder({
    required this.id,
    required this.deviceId,
    required this.relayIndex,
    required this.startTime,
    required this.duration,
    required this.repeatType,
    this.isActive = true,
  }) : assert(relayIndex >= 0, 'relayIndex must be >= 0');
  
  RelayReminder copyWith({
    String? id,
    String? deviceId,
    int? relayIndex,
    DateTime? startTime,
    Duration? duration,
    ReminderRepeatType? repeatType,
    bool? isActive,
  }) {
    if (duration != null && duration <= Duration.zero) {
      throw ArgumentError('Duration must be positive');
    }
    
    return RelayReminder(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      relayIndex: relayIndex ?? this.relayIndex,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      repeatType: repeatType ?? this.repeatType,
      isActive: isActive ?? this.isActive,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}
```

**Validation rules:**
- `duration` must be positive (> Duration.zero)
- `relayIndex` must be >= 0
- `startTime` should not be far in the past for new reminders (warn, don't throw)

#### RelayStatistics

```dart
class RelayStatistics {
  final String deviceId;
  final int relayIndex;
  final Duration totalOnTime;
  final int activationCount;
  final DateTime? lastActivated;
  
  const RelayStatistics({
    required this.deviceId,
    required this.relayIndex,
    required this.totalOnTime,
    required this.activationCount,
    this.lastActivated,
  });
  
  RelayStatistics copyWith({
    String? deviceId,
    int? relayIndex,
    Duration? totalOnTime,
    int? activationCount,
    DateTime? lastActivated,
  }) {
    return RelayStatistics(
      deviceId: deviceId ?? this.deviceId,
      relayIndex: relayIndex ?? this.relayIndex,
      totalOnTime: totalOnTime ?? this.totalOnTime,
      activationCount: activationCount ?? this.activationCount,
      lastActivated: lastActivated ?? this.lastActivated,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayStatistics &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          relayIndex == other.relayIndex;
  
  @override
  int get hashCode => Object.hash(deviceId, relayIndex);
}
```

#### Device Extension

Add to existing `Device` class:

```dart
class Device {
  // ... existing fields
  
  // Relay-specific (null for non-relay devices)
  final int? relayCount;
  final List<RelayChannel>? relayChannels;
  final String? firmwareVersion;
  final String? appVersion;
  final DateTime? lastConnected;
  
  const Device({
    // ... existing parameters
    this.relayCount,
    this.relayChannels,
    this.firmwareVersion,
    this.appVersion,
    this.lastConnected,
  });
  
  Device copyWith({
    // ... existing parameters
    int? relayCount,
    List<RelayChannel>? relayChannels,
    String? firmwareVersion,
    String? appVersion,
    DateTime? lastConnected,
  }) {
    return Device(
      // ... existing fields
      relayCount: relayCount ?? this.relayCount,
      relayChannels: relayChannels ?? this.relayChannels,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      appVersion: appVersion ?? this.appVersion,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}
```

---

### Swift Implementation

#### RelayChannel

```swift
// kvx/Models/RelayChannel.swift

struct RelayChannel: Equatable, Hashable {
    let index: Int
    let isOn: Bool
    let label: String?
    
    init(index: Int, isOn: Bool, label: String? = nil) {
        self.index = index
        self.isOn = isOn
        self.label = label
    }
    
    // Equatable based on index
    static func == (lhs: RelayChannel, rhs: RelayChannel) -> Bool {
        lhs.index == rhs.index
    }
    
    // Hashable based on index
    func hash(into hasher: inout Hasher) {
        hasher.combine(index)
    }
}
```

#### ReminderRepeatType

```swift
// kvx/Models/ReminderRepeatType.swift

enum ReminderRepeatType: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "Không lặp lại"
        case .daily: return "Hằng ngày"
        case .weekly: return "Hằng tuần"
        case .monthly: return "Hằng tháng"
        }
    }
}
```

#### RelayReminder

```swift
// kvx/Models/RelayReminder.swift

import Foundation

struct RelayReminder: Identifiable, Equatable, Hashable {
    let id: String
    let deviceId: String
    let relayIndex: Int
    let startTime: Date
    let duration: TimeInterval  // seconds
    let repeatType: ReminderRepeatType
    let isActive: Bool
    
    init(
        id: String,
        deviceId: String,
        relayIndex: Int,
        startTime: Date,
        duration: TimeInterval,
        repeatType: ReminderRepeatType,
        isActive: Bool = true
    ) {
        precondition(relayIndex >= 0, "relayIndex must be >= 0")
        precondition(duration > 0, "duration must be positive")
        
        self.id = id
        self.deviceId = deviceId
        self.relayIndex = relayIndex
        self.startTime = startTime
        self.duration = duration
        self.repeatType = repeatType
        self.isActive = isActive
    }
    
    // Equatable based on id
    static func == (lhs: RelayReminder, rhs: RelayReminder) -> Bool {
        lhs.id == rhs.id
    }
    
    // Hashable based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

#### RelayStatistics

```swift
// kvx/Models/RelayStatistics.swift

import Foundation

struct RelayStatistics: Equatable, Hashable {
    let deviceId: String
    let relayIndex: Int
    let totalOnTime: TimeInterval  // seconds
    let activationCount: Int
    let lastActivated: Date?
    
    // Equatable based on deviceId and relayIndex
    static func == (lhs: RelayStatistics, rhs: RelayStatistics) -> Bool {
        lhs.deviceId == rhs.deviceId && lhs.relayIndex == rhs.relayIndex
    }
    
    // Hashable based on deviceId and relayIndex
    func hash(into hasher: inout Hasher) {
        hasher.combine(deviceId)
        hasher.combine(relayIndex)
    }
}
```

#### Device Extension

Add to existing `Device` struct:

```swift
// kvx/Models/Device.swift

struct Device: Identifiable, Equatable, Hashable {
    // ... existing fields
    
    // Relay-specific (nil for non-relay devices)
    let relayCount: Int?
    let relayChannels: [RelayChannel]?
    let firmwareVersion: String?
    let appVersion: String?
    let lastConnected: Date?
    
    init(
        // ... existing parameters
        relayCount: Int? = nil,
        relayChannels: [RelayChannel]? = nil,
        firmwareVersion: String? = nil,
        appVersion: String? = nil,
        lastConnected: Date? = nil
    ) {
        // ... existing assignments
        self.relayCount = relayCount
        self.relayChannels = relayChannels
        self.firmwareVersion = firmwareVersion
        self.appVersion = appVersion
        self.lastConnected = lastConnected
    }
}
```

## Acceptance Criteria

### Flutter
- [ ] All Dart entities compile without errors
- [ ] Entities are immutable (all fields final, const constructor)
- [ ] `copyWith` methods implemented for all entities
- [ ] Equality (`==`) and `hashCode` implemented based on `id` or stable fields
- [ ] `ReminderRepeatType` has Vietnamese display names
- [ ] `RelayReminder` validation logic prevents invalid durations
- [ ] `Device.copyWith` handles all new relay fields
- [ ] No imports from Flutter widgets, HTTP, or presentation layer
- [ ] Unit tests cover:
  - Entity creation
  - `copyWith` behavior
  - Equality checks
  - Validation rules (duration > 0)
  - Null safety (optional fields)

### Swift
- [ ] All Swift structs compile without errors
- [ ] Structs are immutable (let properties)
- [ ] `Equatable` and `Hashable` conformance implemented
- [ ] `ReminderRepeatType` has Vietnamese display names
- [ ] `RelayReminder` initializer validates duration and relayIndex (precondition)
- [ ] `Device` includes all new relay fields as optionals
- [ ] No imports from SwiftUI, URLSession, or view layer
- [ ] Unit tests cover:
  - Struct initialization
  - Equality checks
  - Validation (preconditions trigger for invalid data)
  - Optional field handling

### Cross-Platform Consistency
- [ ] Field names match between Swift and Flutter (camelCase)
- [ ] Data types equivalent (Duration ↔ TimeInterval, DateTime ↔ Date)
- [ ] Validation rules consistent
- [ ] Enum cases and display names identical

## Verification

### Flutter Tests

Run unit tests:

```bash
cd kvx_flutter
flutter test test/domain/entities/
```

Expected: All tests pass, 100% coverage for entity logic.

### Swift Tests

Run unit tests:

```bash
xcodebuild test \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:kvxTests/Models/RelayChannelTests \
  -only-testing:kvxTests/Models/RelayReminderTests \
  -only-testing:kvxTests/Models/RelayStatisticsTests
```

Or via Xcode: `Cmd+U` with test targets selected.

Expected: All tests pass.

## Implementation Notes

### Flutter (Dart)
- Keep entities simple: data holders with equality and copyWith
- Validation should throw `ArgumentError` with clear messages
- Follow existing pattern from `schedule.dart` (enum with displayName)
- Use `@immutable` annotation if importing foundation
- `RelayChannel` index starts at 0 (matches array index)
- `Duration` is already a Dart type, no custom implementation needed
- `DateTime` for timestamps, store in UTC internally (convert in presentation)

### Swift
- Use `struct` for value semantics (copy-on-write)
- Validation via `precondition` in initializer (crashes in debug, but clear errors)
- Follow existing pattern from `Schedule.swift`
- `RelayChannel` index starts at 0 (matches array index)
- `TimeInterval` is Double (seconds), equivalent to Dart Duration
- `Date` for timestamps, store in UTC internally (convert in presentation)
- Conform to `Identifiable` where needed for SwiftUI lists

### Cross-Platform Type Mapping

| Concept | Flutter (Dart) | Swift | Notes |
|---------|----------------|-------|-------|
| Duration | `Duration` | `TimeInterval` | Dart: nanoseconds precision, Swift: seconds (Double) |
| Timestamp | `DateTime` | `Date` | Both represent absolute time |
| String ID | `String` | `String` | Identical |
| Optional | `Type?` | `Type?` | Identical syntax |
| List | `List<T>` | `[T]` | Similar semantics |
| Validation | `ArgumentError` | `precondition` | Different mechanisms, same intent |

## Risks / Limitations

- **Risk**: Validation rules too strict (e.g., rejecting past startTime)
  - **Mitigation**: Only validate critical invariants (duration > 0), warn on suspicious values
  
- **Risk**: Over-engineering with too many fields
  - **Mitigation**: Only add fields confirmed in HTML reference, avoid speculation

- **Limitation**: No history tracking in entities (statistics are aggregates, not history logs)

## Out of Scope

- Repository contracts (Task 02)
- DTO mapping (Task 04)
- API integration (Task 05)
- UI components (Tasks 07-08)
- Use cases (Task 03)

## Follow-Up Tasks

After completion:
- Task 02: Define repository contract for relay operations (both Swift and Flutter)
- Task 03: Implement use cases using these entities (both platforms)
- Cross-platform consistency check: Ensure field names and semantics match

**Estimated Time:**
- Flutter: 2-3 hours
- Swift: 2-3 hours  
- **Total: 4-6 hours** (can be done in parallel by 2 developers)
