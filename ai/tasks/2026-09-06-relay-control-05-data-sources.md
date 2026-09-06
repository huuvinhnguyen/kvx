# Task 05 — Relay Control Data Sources

## Status

Ready to start (depends on Task 04).

## Goal

Implement data sources that provide relay control data. Two parallel implementations:
- **5A**: In-memory datasource with fake data (enables UI development)
- **5B**: BinBlog API datasource with real HTTP calls (production)

## Scope

- Flutter data layer only.
- Implement relay control methods in datasources.
- Handle authentication, errors, and network failures.
- Keep datasources behind `DeviceDataSource` interface.

## Prerequisites

- Task 04 complete: DTOs exist for mapping
- Existing `BinblogDeviceDataSource` understood
- API contract from architecture doc

## Architecture Decision

**Dual datasource strategy**:
1. Start with in-memory (Task 5A) to unblock UI development
2. Implement real API (Task 5B) in parallel or after
3. Repository switches between them via constructor injection
4. Both implement same interface extension

This allows:
- UI team works with fake data immediately
- API team tests endpoints independently
- Easy A/B testing and debugging

## Relevant Existing Files

- `kvx_flutter/lib/data/datasources/device_local_datasource.dart` (interface)
- `kvx_flutter/lib/data/datasources/binblog_device_datasource.dart` (pattern reference)
- `kvx_flutter/lib/data/datasources/in_memory_device_datasource.dart` (pattern reference)
- `kvx_flutter/lib/data/models/binblog_relay_reminder_dto.dart`

## Expected Files

**Modify:**
- `kvx_flutter/lib/data/datasources/device_local_datasource.dart` (extend interface)

**Create:**
- `kvx_flutter/lib/data/datasources/in_memory_relay_datasource.dart`

**Extend:**
- `kvx_flutter/lib/data/datasources/binblog_device_datasource.dart` (add relay methods)

**Test:**
- `kvx_flutter/test/data/datasources/in_memory_relay_datasource_test.dart`
- `kvx_flutter/test/data/datasources/binblog_device_datasource_test.dart` (relay methods)

---

## Part A: DeviceDataSource Interface Extension

First, extend the interface to include relay methods:

```dart
// device_local_datasource.dart

import '../../domain/entities/device.dart';
import '../models/binblog_relay_reminder_dto.dart';
import '../models/binblog_relay_statistics_dto.dart';

abstract class DeviceDataSource {
  // Existing methods
  Future<List<Device>> getDevices();
  Future<void> saveDevices(List<Device> devices);
  
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
  
  // Reminders (work with DTOs at data layer)
  Future<List<BinblogRelayReminderDto>> getReminders({
    required String deviceId,
    required int relayIndex,
  });
  
  Future<BinblogRelayReminderDto> addReminder(
    BinblogRelayReminderDto reminder,
  );
  
  Future<void> removeReminder(String reminderId);
  
  Future<void> toggleReminders({
    required String deviceId,
    required int relayIndex,
    required bool isActive,
  });
  
  // Statistics
  Future<BinblogRelayStatisticsDto> getRelayStatistics({
    required String deviceId,
    required int relayIndex,
  });
  
  // Device control
  Future<Map<String, dynamic>> refreshDevice(String deviceId);
  
  Future<void> restartDevice(String deviceId);
  
  Future<void> resetWifi(String deviceId);
}
```

---

## Part B: Task 5A — In-Memory Relay DataSource

### Implementation

```dart
// in_memory_relay_datasource.dart

import '../../domain/entities/device.dart';
import '../models/binblog_relay_reminder_dto.dart';
import '../models/binblog_relay_statistics_dto.dart';
import 'device_local_datasource.dart';

class InMemoryRelayDataSource implements DeviceDataSource {
  // Simulated state
  final Map<String, Map<int, bool>> _relayStates = {};
  final Map<String, List<BinblogRelayReminderDto>> _reminders = {};
  final Map<String, Map<int, BinblogRelayStatisticsDto>> _statistics = {};
  
  // Configurable delay (simulate network latency)
  final Duration delay;
  
  // Configurable failure rate (for testing error handling)
  final bool shouldFail;
  
  InMemoryRelayDataSource({
    this.delay = const Duration(milliseconds: 300),
    this.shouldFail = false,
  }) {
    _initializeDemoData();
  }
  
  void _initializeDemoData() {
    // Demo device: esp8266_11729385 with 2 relays
    _relayStates['esp8266_11729385'] = {0: false, 1: false};
    
    // Demo reminders
    _reminders['esp8266_11729385'] = [
      BinblogRelayReminderDto(
        id: 'reminder-1',
        deviceId: 'esp8266_11729385',
        relayIndex: 0,
        startTime: '2026-09-06T08:00:00Z',
        duration: 300000, // 5 minutes
        repeatType: 'daily',
        isActive: true,
      ),
    ];
    
    // Demo statistics
    _statistics['esp8266_11729385'] = {
      0: BinblogRelayStatisticsDto(
        deviceId: 'esp8266_11729385',
        relayIndex: 0,
        totalOnTimeMs: 7200000, // 2 hours
        activationCount: 15,
        lastActivated: '2026-09-05T14:30:00Z',
      ),
      1: BinblogRelayStatisticsDto(
        deviceId: 'esp8266_11729385',
        relayIndex: 1,
        totalOnTimeMs: 3600000, // 1 hour
        activationCount: 8,
        lastActivated: '2026-09-05T10:15:00Z',
      ),
    };
  }
  
  Future<void> _simulateDelay() async {
    await Future.delayed(delay);
    if (shouldFail) {
      throw Exception('Simulated network failure');
    }
  }
  
  @override
  Future<void> toggleRelay({
    required String deviceId,
    required int relayIndex,
    required bool isOn,
  }) async {
    await _simulateDelay();
    
    _relayStates.putIfAbsent(deviceId, () => {});
    _relayStates[deviceId]![relayIndex] = isOn;
    
    print('[InMemory] Relay $deviceId:$relayIndex → ${isOn ? "ON" : "OFF"}');
  }
  
  @override
  Future<void> activateRelayForDuration({
    required String deviceId,
    required int relayIndex,
    required Duration duration,
  }) async {
    await _simulateDelay();
    
    // Turn on relay
    _relayStates.putIfAbsent(deviceId, () => {});
    _relayStates[deviceId]![relayIndex] = true;
    
    print('[InMemory] Relay $deviceId:$relayIndex activated for ${duration.inSeconds}s');
    
    // Simulate auto-off after duration (in real app, backend handles this)
    Future.delayed(duration, () {
      _relayStates[deviceId]![relayIndex] = false;
      print('[InMemory] Relay $deviceId:$relayIndex auto-off');
    });
  }
  
  @override
  Future<List<BinblogRelayReminderDto>> getReminders({
    required String deviceId,
    required int relayIndex,
  }) async {
    await _simulateDelay();
    
    final allReminders = _reminders[deviceId] ?? [];
    return allReminders
        .where((r) => r.relayIndex == relayIndex)
        .toList();
  }
  
  @override
  Future<BinblogRelayReminderDto> addReminder(
    BinblogRelayReminderDto reminder,
  ) async {
    await _simulateDelay();
    
    _reminders.putIfAbsent(reminder.deviceId, () => []);
    _reminders[reminder.deviceId]!.add(reminder);
    
    print('[InMemory] Added reminder ${reminder.id}');
    return reminder;
  }
  
  @override
  Future<void> removeReminder(String reminderId) async {
    await _simulateDelay();
    
    for (final deviceReminders in _reminders.values) {
      deviceReminders.removeWhere((r) => r.id == reminderId);
    }
    
    print('[InMemory] Removed reminder $reminderId');
  }
  
  @override
  Future<void> toggleReminders({
    required String deviceId,
    required int relayIndex,
    required bool isActive,
  }) async {
    await _simulateDelay();
    
    final deviceReminders = _reminders[deviceId] ?? [];
    for (int i = 0; i < deviceReminders.length; i++) {
      if (deviceReminders[i].relayIndex == relayIndex) {
        deviceReminders[i] = BinblogRelayReminderDto(
          id: deviceReminders[i].id,
          deviceId: deviceReminders[i].deviceId,
          relayIndex: deviceReminders[i].relayIndex,
          startTime: deviceReminders[i].startTime,
          duration: deviceReminders[i].duration,
          repeatType: deviceReminders[i].repeatType,
          isActive: isActive,
        );
      }
    }
    
    print('[InMemory] Toggled reminders $deviceId:$relayIndex → $isActive');
  }
  
  @override
  Future<BinblogRelayStatisticsDto> getRelayStatistics({
    required String deviceId,
    required int relayIndex,
  }) async {
    await _simulateDelay();
    
    return _statistics[deviceId]?[relayIndex] ??
        BinblogRelayStatisticsDto(
          deviceId: deviceId,
          relayIndex: relayIndex,
          totalOnTimeMs: 0,
          activationCount: 0,
          lastActivated: null,
        );
  }
  
  @override
  Future<Map<String, dynamic>> refreshDevice(String deviceId) async {
    await _simulateDelay();
    
    final relayStates = _relayStates[deviceId] ?? {};
    print('[InMemory] Refreshed device $deviceId');
    
    return {
      'device_id': deviceId,
      'relay_states': relayStates,
      'last_connected': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  Future<void> restartDevice(String deviceId) async {
    await _simulateDelay();
    print('[InMemory] Restarted device $deviceId');
  }
  
  @override
  Future<void> resetWifi(String deviceId) async {
    await _simulateDelay();
    print('[InMemory] Reset WiFi for device $deviceId');
  }
  
  // Implement existing interface methods
  @override
  Future<List<Device>> getDevices() async {
    // Return demo devices or delegate to another datasource
    throw UnimplementedError('Use existing in-memory device datasource');
  }
  
  @override
  Future<void> saveDevices(List<Device> devices) async {
    throw UnimplementedError('Use existing in-memory device datasource');
  }
}
```

### Acceptance Criteria (Task 5A)

- [ ] In-memory datasource implements all relay methods
- [ ] Simulates network delay (configurable)
- [ ] Maintains state (relay on/off, reminders list)
- [ ] Provides demo data for testing
- [ ] Prints debug logs for manual verification
- [ ] Optional failure mode for testing error handling
- [ ] Tests verify state changes correctly

---

## Part C: Task 5B — BinBlog API Integration

### API Endpoints Reference

From architecture doc:

```
POST /api/devices/toggle_relay
POST /api/devices/set_longlast
GET  /api/devices/reminders?chip_id=xxx&relay_index=n
POST /api/devices/add_reminder
DELETE /api/devices/remove_reminder
POST /api/devices/toggle_reminders
GET  /api/devices/relay_statistics?chip_id=xxx&relay_index=n
POST /api/devices/refresh_device
POST /api/devices/restart
POST /api/devices/reset_wifi
```

### Implementation

Extend existing `BinblogDeviceDataSource`:

```dart
// binblog_device_datasource.dart (add to existing class)

class BinblogDeviceDataSource implements DeviceDataSource {
  static const _baseUrl = 'https://khuonvien.vn';
  final String username;
  final String password;
  final http.Client _client;
  
  String? _cachedToken;
  DateTime? _tokenExpiry;
  
  // ... existing methods ...
  
  // Reuse authentication
  Future<String> _getAuthToken() async {
    // Check if cached token is still valid
    if (_cachedToken != null && 
        _tokenExpiry != null && 
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }
    
    // Login and get new token
    final loginResponse = await _client.post(
      Uri.parse('$_baseUrl/api/login'),
      headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    
    if (loginResponse.statusCode != 200) {
      throw BinblogApiException(
        'Đăng nhập thất bại (${loginResponse.statusCode})',
      );
    }
    
    final loginBody = _decodeObject(loginResponse.body);
    final token = loginBody['token'] as String?;
    
    if (token == null || token.isEmpty) {
      throw const BinblogApiException('Không nhận được token');
    }
    
    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
    
    return token;
  }
  
  @override
  Future<void> toggleRelay({
    required String deviceId,
    required int relayIndex,
    required bool isOn,
  }) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/toggle_relay'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'relay_index': relayIndex,
        'is_on': isOn,
      }),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể điều khiển relay (${response.statusCode})',
      );
    }
  }
  
  @override
  Future<void> activateRelayForDuration({
    required String deviceId,
    required int relayIndex,
    required Duration duration,
  }) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/set_longlast'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'relay_index': relayIndex,
        'longlast': duration.inMilliseconds,
      }),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể kích hoạt relay (${response.statusCode})',
      );
    }
  }
  
  @override
  Future<List<BinblogRelayReminderDto>> getReminders({
    required String deviceId,
    required int relayIndex,
  }) async {
    final token = await _getAuthToken();
    
    final uri = Uri.parse('$_baseUrl/api/devices/reminders').replace(
      queryParameters: {
        'chip_id': deviceId,
        'relay_index': relayIndex.toString(),
      },
    );
    
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không lấy được danh sách hẹn giờ (${response.statusCode})',
      );
    }
    
    final body = _decodeObject(response.body);
    final reminders = body['reminders'] as List<dynamic>? ?? [];
    
    return reminders
        .map((item) => BinblogRelayReminderDto.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }
  
  @override
  Future<BinblogRelayReminderDto> addReminder(
    BinblogRelayReminderDto reminder,
  ) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/add_reminder'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(reminder.toJson()),
    );
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw BinblogApiException(
        'Không thể thêm hẹn giờ (${response.statusCode})',
      );
    }
    
    final body = _decodeObject(response.body);
    return BinblogRelayReminderDto.fromJson(body);
  }
  
  @override
  Future<void> removeReminder(String reminderId) async {
    final token = await _getAuthToken();
    
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/devices/remove_reminder'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'id': reminderId}),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể xóa hẹn giờ (${response.statusCode})',
      );
    }
  }
  
  @override
  Future<void> toggleReminders({
    required String deviceId,
    required int relayIndex,
    required bool isActive,
  }) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/toggle_reminders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'relay_index': relayIndex,
        'is_active': isActive,
      }),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể bật/tắt hẹn giờ (${response.statusCode})',
      );
    }
  }
  
  @override
  Future<BinblogRelayStatisticsDto> getRelayStatistics({
    required String deviceId,
    required int relayIndex,
  }) async {
    final token = await _getAuthToken();
    
    final uri = Uri.parse('$_baseUrl/api/devices/relay_statistics').replace(
      queryParameters: {
        'chip_id': deviceId,
        'relay_index': relayIndex.toString(),
      },
    );
    
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không lấy được thống kê (${response.statusCode})',
      );
    }
    
    final body = _decodeObject(response.body);
    return BinblogRelayStatisticsDto.fromJson(body);
  }
  
  @override
  Future<Map<String, dynamic>> refreshDevice(String deviceId) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/refresh_device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'chip_id': deviceId}),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể làm mới thiết bị (${response.statusCode})',
      );
    }
    
    return _decodeObject(response.body);
  }
  
  @override
  Future<void> restartDevice(String deviceId) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/restart'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'chip_id': deviceId}),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể khởi động lại thiết bị (${response.statusCode})',
      );
    }
  }
  
  @override
  Future<void> resetWifi(String deviceId) async {
    final token = await _getAuthToken();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/devices/reset_wifi'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'chip_id': deviceId}),
    );
    
    if (response.statusCode != 200) {
      throw BinblogApiException(
        'Không thể reset WiFi (${response.statusCode})',
      );
    }
  }
}
```

### Acceptance Criteria (Task 5B)

- [ ] All relay methods implemented with real API calls
- [ ] Authentication token reused across requests
- [ ] Token caching implemented (avoid re-login every request)
- [ ] Proper HTTP methods used (GET, POST, DELETE)
- [ ] Request bodies match API contract
- [ ] Response parsing handles success and errors
- [ ] Vietnamese error messages for user display
- [ ] HTTP client is mockable for testing
- [ ] Tests with mock HTTP client verify correct requests
- [ ] Manual test with real backend succeeds

## Verification

### Task 5A (In-Memory)

```bash
cd kvx_flutter
flutter test test/data/datasources/in_memory_relay_datasource_test.dart
```

### Task 5B (BinBlog API)

```bash
cd kvx_flutter
flutter test test/data/datasources/binblog_device_datasource_test.dart
```

Manual test with real device:
```bash
# Set credentials
export BINBLOG_USERNAME="your-username"
export BINBLOG_PASSWORD="your-password"

# Run app and test relay toggle
flutter run
```

## Implementation Notes

### Error Handling

All datasource methods should throw descriptive exceptions:
- `BinblogApiException` for API errors
- Include status code and user-friendly message
- Don't log sensitive data (tokens, passwords)

### Token Management

- Cache token to avoid re-login on every request
- Check token expiry before reuse
- Refresh token if expired
- Clear token on 401 response

### Testing Strategy

**In-Memory Tests:**
- Verify state changes
- Test delay simulation
- Test failure mode

**BinBlog API Tests:**
- Mock HTTP client
- Verify request URL, method, headers, body
- Test various response codes (200, 401, 500)
- Test network exceptions

## Risks / Limitations

- **Risk**: API contract mismatch (field names, types)
  - **Mitigation**: Start with Task 5A, test 5B early with real backend

- **Risk**: Token expiry during long session
  - **Mitigation**: Token refresh logic, expiry tracking

- **Risk**: Network timeout (no timeout configured)
  - **Mitigation**: Add timeout to HTTP client (future improvement)

- **Limitation**: No offline queue (requests fail immediately when offline)
  - **Rationale**: Out of scope for MVP

## Out of Scope

- Request retry logic
- Offline queue/sync
- WebSocket for realtime updates
- Request cancellation
- Response caching

## Follow-Up Tasks

After completion:
- Task 06: Implement repository using one of these datasources
- Integration test: Real API → Datasource → DTO → Domain
