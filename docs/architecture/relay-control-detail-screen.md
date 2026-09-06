# Architecture Decision: Relay Control Detail Screen

## Context

Cần xây dựng màn hình chi tiết cho thiết bị relay (công tắc thông minh) với các tính năng:
- Điều khiển BẬT/TẮT relay theo kênh (2 kênh)
- Kích hoạt relay trong khoảng thời gian xác định (longlast)
- Hẹn giờ bật/tắt relay với lịch lặp lại (daily/weekly/monthly)
- Hiển thị danh sách hẹn giờ và bật/tắt hẹn giờ
- Xem thống kê sử dụng theo từng kênh relay
- Điều khiển thiết bị (làm mới, khởi động lại, đổi WiFi)

HTML reference đã được cung cấp từ hệ thống web hiện tại (Rails) với thiết bị `esp8266_11729385` có 2 relay channels.

## Constraints

- **Platform**: Flutter (kvx_flutter)
- **Dependencies**: Existing device repository, presentation patterns
- **Architecture**: Clean Architecture (Domain → Application → Data → Presentation)
- **Current State**: Device detail screen đã có sẵn với control switch đơn giản và schedule đơn giản
- **Hardware**: ESP8266 với 2 relay channels, có thể kích hoạt theo thời gian (longlast) hoặc hẹn giờ (reminders)
- **Backend**: API endpoints cần được gọi qua repository pattern

## Approach

Mở rộng kiến trúc hiện tại để hỗ trợ relay control với multiple channels, longlast activation, và reminder management.

## Layer Changes

### Domain

**Entities cần bổ sung:**

1. **RelayChannel** (mới):
   ```dart
   class RelayChannel {
     final int index;           // 0, 1, ...
     final bool isOn;           // trạng thái hiện tại
     final String? label;       // "Kênh 1", "Kênh 2"
   }
   ```

2. **RelayReminder** (mới):
   ```dart
   class RelayReminder {
     final String id;
     final String deviceId;
     final int relayIndex;
     final DateTime startTime;
     final Duration duration;
     final ReminderRepeatType repeatType;
     final bool isActive;
   }
   
   enum ReminderRepeatType { none, daily, weekly, monthly }
   ```

3. **RelayStatistics** (mới):
   ```dart
   class RelayStatistics {
     final String deviceId;
     final int relayIndex;
     final Duration totalOnTime;
     final int activationCount;
     final DateTime? lastActivated;
   }
   ```

4. **Device** (mở rộng):
   ```dart
   class Device {
     // ... existing fields
     final int? relayCount;        // số kênh relay (null nếu không phải relay device)
     final List<RelayChannel>? relayChannels;
     final String? firmwareVersion;
     final String? appVersion;
     final DateTime? lastConnected;
   }
   ```

**Repository Contracts:**

```dart
// Thêm vào DeviceRepository
abstract class DeviceRepository {
  // ... existing methods
  
  // Relay control
  Future<void> toggleRelay(String deviceId, int relayIndex, bool isOn);
  Future<void> activateRelayForDuration(String deviceId, int relayIndex, Duration duration);
  
  // Reminders
  Future<List<RelayReminder>> getReminders(String deviceId, int relayIndex);
  Future<void> addReminder(RelayReminder reminder);
  Future<void> removeReminder(String reminderId);
  Future<void> toggleReminders(String deviceId, int relayIndex, bool isActive);
  
  // Statistics
  Future<RelayStatistics> getRelayStatistics(String deviceId, int relayIndex);
  
  // Device control
  Future<void> refreshDevice(String deviceId);
  Future<void> restartDevice(String deviceId);
  Future<void> resetWifi(String deviceId);
}
```

### Application

**Use Cases mới:**

1. **ToggleRelayUseCase**:
   ```dart
   Future<void> execute(String deviceId, int relayIndex, bool isOn)
   ```

2. **ActivateRelayForDurationUseCase**:
   ```dart
   Future<void> execute(String deviceId, int relayIndex, Duration duration)
   ```

3. **ManageRelayReminderUseCase**:
   ```dart
   Future<void> addReminder(RelayReminder reminder)
   Future<void> removeReminder(String reminderId)
   Future<void> toggleReminders(String deviceId, int relayIndex, bool isActive)
   ```

4. **GetRelayStatisticsUseCase**:
   ```dart
   Future<RelayStatistics> execute(String deviceId, int relayIndex)
   ```

5. **ControlDeviceUseCase**:
   ```dart
   Future<void> refresh(String deviceId)
   Future<void> restart(String deviceId)
   Future<void> resetWifi(String deviceId)
   ```

### Data

**DTO Models:**

1. **BinblogRelayChannelDTO**:
   ```dart
   class BinblogRelayChannelDTO {
     final int index;
     final bool is_on;
     final String? label;
     
     // fromJson, toJson
   }
   ```

2. **BinblogRelayReminderDTO**:
   ```dart
   class BinblogRelayReminderDTO {
     final String id;
     final String device_id;
     final int relay_index;
     final String start_time;      // ISO 8601
     final int duration;            // milliseconds
     final String repeat_type;      // "none", "daily", "weekly", "monthly"
     final bool is_active;
     
     // fromJson, toJson, toDomain
   }
   ```

**API Endpoints (cần implement trong datasource):**

```dart
// POST /api/devices/toggle_relay
// Body: { device_id, relay_index, is_on }

// POST /api/devices/set_longlast
// Body: { device_id, relay_index, longlast (milliseconds) }

// GET /api/devices/reminders?chip_id=xxx&relay_index=n
// POST /api/devices/add_reminder
// DELETE /api/devices/remove_reminder
// POST /api/devices/toggle_reminders

// GET /api/devices/relay_statistics?chip_id=xxx&relay_index=n

// POST /api/devices/refresh_device
// POST /api/devices/restart
// POST /api/devices/reset_wifi
```

**Repository Implementation:**

Mở rộng `DeviceRepositoryImpl` để implement các phương thức relay control mới.

### Presentation

**Screens mới:**

1. **RelayDeviceDetailScreen** (thay thế DeviceDetailScreen cho relay devices):
   - Header: thông tin thiết bị, last connected, firmware/app version
   - Tab view cho mỗi relay channel (Kênh 1, Kênh 2)
   - Mỗi tab có:
     - Toggle switch BẬT/TẮT
     - Form kích hoạt theo thời gian (longlast)
     - Form hẹn giờ (reminder)
     - Danh sách hẹn giờ với toggle all reminders
     - Nút xem thống kê
   - Footer: nút khởi động lại, thay đổi WiFi

2. **RelayStatisticsScreen** (mới):
   - Hiển thị thống kê sử dụng relay theo channel
   - Tổng thời gian bật
   - Số lần kích hoạt
   - Lần kích hoạt cuối

**Provider/State Management:**

```dart
class RelayDeviceProvider extends ChangeNotifier {
  final ToggleRelayUseCase toggleRelayUseCase;
  final ActivateRelayForDurationUseCase activateForDurationUseCase;
  final ManageRelayReminderUseCase manageReminderUseCase;
  final GetRelayStatisticsUseCase getStatisticsUseCase;
  final ControlDeviceUseCase controlDeviceUseCase;
  
  Device? _device;
  List<RelayReminder> _reminders = [];
  bool _isLoading = false;
  String? _error;
  int _selectedRelayIndex = 0;
  
  // Methods:
  Future<void> toggleRelay(int relayIndex, bool isOn)
  Future<void> activateForDuration(int relayIndex, Duration duration)
  Future<void> addReminder(RelayReminder reminder)
  Future<void> removeReminder(String reminderId)
  Future<void> toggleReminders(int relayIndex, bool isActive)
  Future<void> loadReminders(int relayIndex)
  Future<void> refreshDevice()
  Future<void> restartDevice()
  Future<void> resetWifi()
  
  void selectRelayChannel(int index)
}
```

**Navigation:**

```dart
// From device list:
if (device.type == DeviceType.switchDevice && device.relayCount != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RelayDeviceDetailScreen(device: device),
    ),
  );
} else {
  // Existing DeviceDetailScreen
}

// To statistics:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => RelayStatisticsScreen(
      deviceId: device.id,
      relayIndex: selectedRelayIndex,
    ),
  ),
);
```

## Alternatives Considered

### Option A: Single Screen for All Device Types

**Pros:**
- Ít code duplication
- Dễ maintain navigation logic

**Cons:**
- Screen phức tạp với quá nhiều conditional rendering
- Khó test từng loại device riêng biệt
- Khó mở rộng khi thêm device type mới

### Option B: Separate Screen cho mỗi Device Type (Chosen)

**Pros:**
- Clean separation of concerns
- Dễ test và maintain
- Dễ customize UI cho từng device type
- Follows clean architecture principles

**Cons:**
- Có thể có một số code duplication (mitigated bằng shared widgets)

### Option C: Generic Detail Screen với Plugin System

**Pros:**
- Highly extensible
- Clean abstraction

**Cons:**
- Over-engineering cho current scope
- Phức tạp không cần thiết cho 2-3 device types

## Decision Rationale

**Chọn Option B** vì:

1. **Separation of Concerns**: Relay device có logic phức tạp hoàn toàn khác với temperature sensor (read-only) và switch device đơn giản
2. **Maintainability**: Mỗi screen tập trung vào một loại device, dễ đọc và maintain
3. **Testability**: Test relay control logic độc lập với sensor logic
4. **Future Extensibility**: Dễ thêm device type mới mà không ảnh hưởng existing screens
5. **UI/UX**: Mỗi device type có thể có UI hoàn toàn khác nhau, tối ưu cho use case riêng

## Implementation Steps

### Phase 1: Domain Layer
1. ✅ Tạo `RelayChannel` entity
2. ✅ Tạo `RelayReminder` entity với `ReminderRepeatType` enum
3. ✅ Tạo `RelayStatistics` entity
4. ✅ Mở rộng `Device` entity với relay-specific fields
5. ✅ Thêm relay control methods vào `DeviceRepository` interface

### Phase 2: Application Layer
6. ✅ Implement `ToggleRelayUseCase`
7. ✅ Implement `ActivateRelayForDurationUseCase`
8. ✅ Implement `ManageRelayReminderUseCase`
9. ✅ Implement `GetRelayStatisticsUseCase`
10. ✅ Implement `ControlDeviceUseCase`

### Phase 3: Data Layer
11. ✅ Tạo DTOs: `BinblogRelayChannelDTO`, `BinblogRelayReminderDTO`, `BinblogRelayStatisticsDTO`
12. ✅ Implement API endpoints trong `BinblogDeviceDataSource`:
    - `toggleRelay()`
    - `activateRelayForDuration()`
    - `getReminders()`
    - `addReminder()`
    - `removeReminder()`
    - `toggleReminders()`
    - `getRelayStatistics()`
    - `refreshDevice()`
    - `restartDevice()`
    - `resetWifi()`
13. ✅ Update `DeviceRepositoryImpl` để implement relay control methods
14. ✅ Handle error cases và network failures

### Phase 4: Presentation Layer
15. ✅ Tạo shared widgets:
    - `RelayToggleSwitch`
    - `RelayLonglastForm`
    - `RelayReminderForm`
    - `RelayReminderList`
    - `DeviceInfoHeader`
16. ✅ Implement `RelayDeviceProvider` với state management
17. ✅ Tạo `RelayDeviceDetailScreen` với tab view cho channels
18. ✅ Tạo `RelayStatisticsScreen`
19. ✅ Update navigation logic trong device list
20. ✅ Handle loading states, errors, và user feedback

### Phase 5: Testing & Polish
21. ✅ Unit tests cho entities và use cases
22. ✅ Unit tests cho repository với mock datasource
23. ✅ Widget tests cho relay control widgets
24. ✅ Integration tests cho complete relay control flow
25. ✅ Manual testing với real device (esp8266_11729385)
26. ✅ Polish UI: spacing, colors, fonts theo design system
27. ✅ Add error handling và user-friendly messages
28. ✅ Accessibility: labels, semantic widgets

## Testing Strategy

### Unit Tests

**Domain:**
- `RelayReminder` entity validation (duration, repeat type)
- `Device` với relay channels creation và copyWith

**Application:**
- `ToggleRelayUseCase` với mock repository
- `ManageRelayReminderUseCase` add/remove/toggle logic
- Error handling trong use cases

**Data:**
- DTO mapping: `BinblogRelayReminderDTO.toDomain()`
- Repository implementation với mock datasource
- Network error handling

### Widget Tests

- `RelayToggleSwitch` interaction
- `RelayLonglastForm` validation (input số, unit selection)
- `RelayReminderForm` datetime picker và validation
- `RelayReminderList` render và delete action
- Tab switching trong `RelayDeviceDetailScreen`

### Integration Tests

- Complete flow: open device → toggle relay → verify state
- Add reminder → verify in list → remove reminder
- Activate longlast → show success message
- Error handling: network failure → show error → retry

### Manual Testing

- Test với real ESP8266 device qua API
- Verify relay thực sự bật/tắt
- Test reminder triggers (nếu backend hỗ trợ)
- Test trên nhiều screen sizes
- Test dark mode và light mode
- Test accessibility với screen reader

## API Contract Notes

Dựa trên HTML reference, các API endpoints cần thiết:

1. **POST /api/devices/toggle_relay**
   - Request: `{ device_id: string, relay_index: int, is_on: bool }`
   - Response: success/error

2. **POST /api/devices/set_longlast**
   - Request: `{ device_id: string, relay_index: int, longlast: int (ms) }`
   - Response: success/error

3. **POST /api/devices/add_reminder**
   - Request: `{ device_id, relay_index, start_time, duration (ms), repeat_type }`
   - Response: `{ id, ... }`

4. **GET /api/devices/reminders**
   - Query: `?chip_id=xxx&relay_index=n`
   - Response: `{ reminders: [...] }`

5. **DELETE /api/devices/remove_reminder**
   - Request: `{ id: string }`
   - Response: success/error

6. **POST /api/devices/toggle_reminders**
   - Request: `{ device_id, relay_index, is_active: bool }`
   - Response: success/error

7. **GET /api/devices/relay_statistics**
   - Query: `?chip_id=xxx&relay_index=n`
   - Response: statistics data

8. **POST /api/devices/refresh_device**
   - Request: `{ chip_id: string }`
   - Response: updated device state

9. **POST /api/devices/restart**
   - Request: `{ chip_id: string }`
   - Response: success/error (với confirmation)

10. **POST /api/devices/reset_wifi**
    - Request: `{ chip_id: string }`
    - Response: success/error (với confirmation)

## UI Components Structure

```
RelayDeviceDetailScreen
├── DeviceInfoHeader
│   ├── Device name, type, status badge
│   ├── Last connected timestamp
│   └── Firmware/App version
├── TabView (Kênh 1, Kênh 2)
│   ├── RelayToggleSwitch
│   │   └── Large switch với BẬT/TẮT label
│   ├── RelayLonglastForm
│   │   ├── Number input
│   │   ├── Unit dropdown (Giây/Phút)
│   │   └── KÍCH HOẠT button
│   ├── Statistics button
│   ├── RelayReminderForm
│   │   ├── DateTime picker
│   │   ├── Duration input (number + unit)
│   │   ├── Repeat type dropdown
│   │   └── Hẹn giờ button
│   └── RelayReminderList
│       ├── Header với toggle all reminders
│       └── List of reminders (time, repeat type, delete button)
└── DeviceControlFooter
    ├── Device ID, firmware, app version
    ├── Làm mới button
    ├── Khởi động lại button (with confirmation)
    └── Thay đổi WiFi button (with confirmation)
```

## Design Decisions

### Multi-Channel Tab View
- **Decision**: Sử dụng TabView thay vì dropdown hoặc stacked cards
- **Rationale**: HTML reference dùng tabs, familiar pattern, dễ switch giữa channels
- **Alternative**: Stacked cards (too much scrolling), dropdown (hidden context)

### Longlast Input Format
- **Decision**: Number input + unit dropdown (Giây/Phút), convert to milliseconds
- **Rationale**: User-friendly, matches HTML reference, avoid confusion với milliseconds
- **Implementation**: Client-side conversion, validate positive integer

### Reminder DateTime
- **Decision**: Single datetime picker (not separate date and time)
- **Rationale**: Simpler UX, Flutter `showDatePicker` + `showTimePicker` combination
- **Format**: ISO 8601 khi gửi lên server

### Confirmation Dialogs
- **Decision**: Show confirmation cho restart và reset WiFi
- **Rationale**: Destructive actions, matches HTML `data-confirm` attribute
- **Implementation**: `AlertDialog` với Yes/No buttons

### Statistics Screen
- **Decision**: Separate screen thay vì modal
- **Rationale**: Có thể mở rộng với charts sau này, full screen flexibility
- **Navigation**: Push new route, can add charts/graphs later

## Risks and Mitigation

### Risk 1: API Endpoints chưa implement đầy đủ
- **Mitigation**: Implement với in-memory datasource trước, switch to BinBlog sau
- **Fallback**: Mock data cho testing và development

### Risk 2: Realtime relay state updates
- **Mitigation**: User phải tap "Làm mới" để get latest state (MVP)
- **Future**: WebSocket hoặc polling cho realtime updates

### Risk 3: Reminder execution logic
- **Mitigation**: Backend responsibility, client chỉ CRUD reminders
- **Assumption**: Backend có scheduler để trigger reminders

### Risk 4: Timezone handling
- **Mitigation**: Luôn dùng UTC cho API, convert to local time trong UI
- **Testing**: Test với multiple timezones

### Risk 5: Multiple concurrent longlast activations
- **Mitigation**: Disable button khi request đang pending
- **Backend**: Backend xử lý queue và conflicts

## Future Enhancements (Out of Scope)

- Realtime relay state updates qua WebSocket
- Historical usage charts trong statistics
- Relay naming (custom labels cho channels)
- Relay grouping (control multiple relays cùng lúc)
- Conditional automation (if temp > X then turn on relay)
- Push notifications khi reminder triggers
- Offline support với sync khi reconnect
- Celsius/Fahrenheit preference cho sensor integration

## Dependencies

- Existing: `device_repository.dart`, `device_provider.dart`, `device.dart`, `schedule.dart`
- New: Time parsing library (built-in Dart `DateTime`)
- New: Tab controller (built-in Flutter `TabController`)
- UI: Material 3 components, existing design system

## Acceptance Criteria

- [ ] User có thể toggle relay bật/tắt từ UI
- [ ] User có thể kích hoạt relay trong khoảng thời gian xác định (longlast)
- [ ] User có thể thêm/xóa hẹn giờ với repeat type
- [ ] User có thể bật/tắt tất cả reminders của một channel
- [ ] User có thể xem thống kê sử dụng relay
- [ ] User có thể làm mới device state
- [ ] User có thể khởi động lại device (với confirmation)
- [ ] User có thể reset WiFi (với confirmation)
- [ ] UI hiển thị loading state khi thực hiện actions
- [ ] UI hiển thị error messages khi action fails
- [ ] Tab switching giữa relay channels hoạt động mượt
- [ ] Form validation hoạt động đúng (positive integers, valid datetime)
- [ ] UI responsive và accessible (VoiceOver, Dynamic Type)
- [ ] Dark mode và light mode hoạt động đúng

## Documentation

- Update `ARCHITECTURE.md` với relay control patterns
- Add API contract documentation trong `docs/api/relay-control-api.md`
- Add user guide trong `docs/user-guide/relay-devices.md`
- Update `CHANGELOG.md` với new features
