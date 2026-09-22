# Task #13: Buzzer Feature Implementation Plan

**GitHub Issue**: https://github.com/huuvinhnguyen/kvx/issues/13  
**Backend Issue**: https://github.com/huuvinhnguyen/binblog/issues/101  
**Backend API Contract**: `/Users/vinhnguyen/Documents/ror/binblog/docs/API_BUZZER_MOBILE.md`

---

## Current Architecture

### Swift

**Location**: `kvx/` (native iOS application)

**Structure**:
- **Domain layer**: `kvx/Domain/`
  - Entities: `kvx/Models/` (BuzzerDetail, BuzzerSource, BuzzerMotionEvent, BuzzerCommand, BuzzerError)
  - Repository contracts: `kvx/Domain/Repositories/BuzzerRepository.swift`
  - Use cases: `kvx/Domain/UseCases/BuzzerUseCases.swift`
- **Data layer**: `kvx/Data/`, `kvx/Services/`
  - API client: `kvx/Services/BuzzerAPIClient.swift`
  - Auth: `kvx/Data/Auth/UserDefaultsAccessTokenProvider.swift` (reads `binblog.accessToken` from UserDefaults)
  - DTO mapping: inline in `BuzzerAPIClient.swift` as `BuzzerDetailDTO`
- **Presentation layer**: `kvx/Views/`, `kvx/ViewModels/`
  - ViewModel: `kvx/ViewModels/BuzzerViewModel.swift` (@Observable, async/await, generation-based cancellation)
  - View: `kvx/Views/Buzzer/BuzzerDetailView.swift` (SwiftUI List, sheet login, confirmation alerts)
- **Tests**: `kvxTests/BuzzerTests.swift` (Swift Testing framework)

**Current implementation**:
- ✅ API endpoint: `GET /api/buzzers/:id` and `POST /api/buzzers/:id/{test,refresh,restart,reset_wifi}`
- ✅ DTO decoding with validation (sources/events uniqueness, duration bounds, ISO8601 dates)
- ✅ Domain model: `BuzzerDetail` with `canTest`, `BuzzerSource`, `BuzzerMotionEvent`
- ✅ Repository: `BuzzerAPIClient` implements `BuzzerRepository`
- ✅ Use case: `BuzzerUseCases` validates test duration before sending
- ✅ ViewModel: async load/send, cooldown tracking, generation-based cancellation, needsLogin flag
- ✅ UI: device header, test section with cooldown, sources list, events history, metadata, device management
- ✅ Error handling: 401 (needsLogin), 404/403 (unavailable), 422 (invalidConfiguration), 429 (cooldown)
- ✅ Tests: DTO mapping, use case validation, ViewModel state management, HTTP integration

**Status**: **ALREADY IMPLEMENTED**. The Swift implementation is complete and matches the existing backend API contract.

---

### Flutter

**Location**: `kvx_flutter/`

**Structure**:
- **Domain layer**: `lib/domain/`
  - Entities: `lib/domain/entities/buzzer_detail.dart` (BuzzerDetail, BuzzerSource, BuzzerMotionEvent, BuzzerCommand, BuzzerFailure)
  - Repository contract: `lib/domain/repositories/buzzer_repository.dart`
- **Application layer**: `lib/application/`
  - Use cases: `lib/application/usecases/buzzer_usecases.dart`
- **Data layer**: `lib/data/`
  - Repository implementation: `lib/data/repositories/binblog_buzzer_repository.dart`
  - DTO: `lib/data/models/buzzer_detail_dto.dart`
  - Data source: `lib/data/datasources/binblog_device_datasource.dart` (shared, reuses login/token)
- **Presentation layer**: `lib/presentation/`
  - Provider: `lib/presentation/providers/buzzer_provider.dart` (ChangeNotifier, Timer for cooldown UI updates)
  - Screen: `lib/presentation/screens/buzzer_detail_screen.dart` (Material widgets, Card-based layout)
- **Tests**: `test/buzzer/buzzer_test.dart` (comprehensive unit, integration, widget tests)

**Current implementation**:
- ✅ API endpoint: `GET /api/buzzers/:id` and `POST /api/buzzers/:id/{test,refresh,restart,reset_wifi}`
- ✅ DTO decoding with validation (timestamp offset check, source/event uniqueness, duration ≥ 0)
- ✅ Domain model: `BuzzerDetail` with `canTest` getter
- ✅ Repository: `BinblogBuzzerRepository` uses shared `BinblogDeviceDataSource`
- ✅ Use case: `BuzzerUseCases` validates test duration before sending
- ✅ Provider: async load/send, cooldown tracking with Timer, generation-based cancellation, needsLogin flag
- ✅ UI: Card-based layout, device header, test button with cooldown countdown, sources/events, metadata, device management
- ✅ Error handling: 401 (authentication), 404/403 (unavailable), 422 (configuration), 429 (cooldown with retry-after)
- ✅ Tests: DTO mapping, use case validation, provider state, HTTP integration, widget tests for both light/dark modes

**Status**: **ALREADY IMPLEMENTED**. The Flutter implementation is complete and matches the existing backend API contract.

---

## Shared Feature Behavior

Both Swift and Flutter implementations **already provide** identical behavior:

1. **Device identity**: Shows device name, chip ID, online/offline/busy status from shared `/api/devices` endpoint
2. **Last connection**: Displays `last_seen` from Buzzer API or `last_connected` from device list as fallback
3. **Linked PIR count**: Shows `sources.length` (PIRs configured to trigger this Buzzer)
4. **Linked PIR list**: Displays each source with name, chip_id, relay_index, duration_ms
5. **Latest trigger time**: Shows `events.first?.occurredAt` (most recent PIR motion event)
6. **Test Buzzer**: 
   - Validates `testDurationMS` in range [100, 10000]
   - Enforces cooldown (client-side after success, server-side from 429 response)
   - Confirmation dialog before sending
   - Shows "command sent to MQTT broker" acknowledgment (NOT physical execution confirmation)
   - Automatically reloads data after command (read-only, never replays mutation)
7. **Recent history**: Displays up to 20 `BuzzerMotionEvent` with source name, chip_id, occurred_at, duration_ms
8. **Device management**: Refresh, Restart, Reset WiFi commands with confirmation dialogs
9. **Loading/error/empty states**:
   - Loading indicator while fetching
   - Error message with retry button
   - Empty state for no sources/events
   - 401 → needsLogin flag, clears data, prompts login
   - 404/403 → clears data, shows "unavailable" message
   - 422 → shows "invalid configuration" message
   - 429 → cooldown enforcement with countdown
10. **Metadata**: Shows build_version, app_version when available

---

## Backend API Contract Discrepancy

**CRITICAL FINDING**: The **Swift and Flutter implementations use a DIFFERENT API contract** than the one documented in `binblog/docs/API_BUZZER_MOBILE.md`.

### Documented API (binblog #101):
```
GET /api/devices/:id/buzzer
GET /api/devices/:id/buzzer/linked_pirs
GET /api/devices/:id/buzzer/history
POST /api/devices/:id/buzzer/test
```

Response structure:
```json
{
  "status": "success",
  "buzzer": {
    "id": 42,
    "linked_pir_count": 2,
    "last_triggered_at": "..."
  },
  "linked_pirs": [...],
  "events": [...]
}
```

### Implemented API (both Swift and Flutter):
```
GET /api/buzzers/:id
POST /api/buzzers/:id/test
POST /api/buzzers/:id/refresh
POST /api/buzzers/:id/restart
POST /api/buzzers/:id/reset_wifi
```

Response structure:
```json
{
  "id": "59",
  "name": "Buzzer",
  "chip_id": "...",
  "online": true,
  "last_seen": "...",
  "sources": [{
    "id": "...",
    "name": "...",
    "chip_id": "...",
    "relay_index": 0,
    "duration_ms": 1000
  }],
  "events": [{
    "id": "...",
    "source_id": "...",
    "source_name": "...",
    "source_chip_id": "...",
    "occurred_at": "...",
    "duration_ms": 1000
  }]
}
```

**Resolution Required**: 
- Option A: Backend implements the API endpoints the mobile apps are **already using** (`/api/buzzers/:id`)
- Option B: Mobile apps are updated to use the **documented** API (`/api/devices/:id/buzzer`)

**Recommendation**: Use **Option A** (keep existing `/api/buzzers/:id` endpoint) because:
1. Both mobile implementations are complete and tested
2. Tests reference fixture file `kvxTests/Fixtures/buzzer-detail.json` with this structure
3. Changing mobile would require rewriting all tests, DTOs, repositories, and re-testing both platforms
4. The existing API is more efficient (single GET returns all data vs. 3 separate requests)

---

## Swift Implementation

### Status: ✅ **COMPLETE** — No changes needed

All files already exist and are fully implemented:

**Domain**:
- ✅ `kvx/Models/BuzzerDetail.swift` — domain entities
- ✅ `kvx/Domain/Repositories/BuzzerRepository.swift` — repository protocol
- ✅ `kvx/Domain/UseCases/BuzzerUseCases.swift` — use case with validation

**Data**:
- ✅ `kvx/Services/BuzzerAPIClient.swift` — API client with DTO mapping
- ✅ `kvx/Data/Auth/UserDefaultsAccessTokenProvider.swift` — token provider (already exists)

**Presentation**:
- ✅ `kvx/ViewModels/BuzzerViewModel.swift` — observable state management
- ✅ `kvx/Views/Buzzer/BuzzerDetailView.swift` — SwiftUI UI

**Tests**:
- ✅ `kvxTests/BuzzerTests.swift` — comprehensive unit tests
- ✅ `kvxTests/Fixtures/buzzer-detail.json` — shared test fixture

**Navigation**: Already integrated into device detail routing (type-based navigation).

---

## Flutter Implementation

### Status: ✅ **COMPLETE** — No changes needed

All files already exist and are fully implemented:

**Domain**:
- ✅ `lib/domain/entities/buzzer_detail.dart` — domain entities
- ✅ `lib/domain/repositories/buzzer_repository.dart` — repository interface

**Application**:
- ✅ `lib/application/usecases/buzzer_usecases.dart` — use case with validation

**Data**:
- ✅ `lib/data/repositories/binblog_buzzer_repository.dart` — repository implementation
- ✅ `lib/data/models/buzzer_detail_dto.dart` — DTO with validation
- ✅ `lib/data/datasources/binblog_device_datasource.dart` — shared data source (already exists)

**Presentation**:
- ✅ `lib/presentation/providers/buzzer_provider.dart` — ChangeNotifier state management
- ✅ `lib/presentation/screens/buzzer_detail_screen.dart` — Material UI

**Tests**:
- ✅ `test/buzzer/buzzer_test.dart` — comprehensive tests (unit, integration, widget)

**Navigation**: Already integrated into device detail routing (type-based navigation).

---

## API Mapping

Both implementations use the **same API endpoints**:

### GET /api/buzzers/:id (Detail)

**Swift**: `BuzzerAPIClient.detail(deviceID:)` → `BuzzerDetailDTO.toDomain()` → `BuzzerDetail`  
**Flutter**: `BinblogBuzzerRepository.load(deviceId)` → `BuzzerDetailDto.fromJson()` → `BuzzerDetail`

**Response fields** (both platforms decode identically):
- `id`, `name`, `chip_id` → device identity
- `online`, `last_seen` → connection status
- `build_version`, `app_version`, `test_duration_ms` → metadata/config
- `sources[]` → linked PIRs (id, name, chip_id, relay_index, duration_ms)
- `events[]` → motion history (id, source_id, source_name, source_chip_id, occurred_at, duration_ms)

### POST /api/buzzers/:id/{command} (Actions)

**Swift**: `BuzzerAPIClient.send(_:deviceID:)` → `BuzzerCommandReceipt`  
**Flutter**: `BinblogBuzzerRepository.send(deviceId, command)` → `BuzzerCommandReceipt`

**Commands**: `test`, `refresh`, `restart`, `reset_wifi`

**Request body**: `{}` (empty JSON object)

**Response**:
- 200: `{"status":"accepted","acknowledgement":"broker_only","cooldown_seconds":3}`
- 401: Missing/invalid JWT → `needsLogin` state
- 403/404: Device not accessible/not found → `unavailable` error
- 422: Invalid configuration → `invalidConfiguration`/`configuration` error
- 429: Cooldown active → `cooldown(seconds)` error with `retry-after` header

---

## Cross-Platform Consistency

### API Semantics
✅ Both use **identical endpoint paths** and request/response structure  
✅ Both validate device ID format (numeric ASCII only)  
✅ Both use Bearer token authentication  
✅ Both decode ISO8601 timestamps with offset validation  
✅ Both enforce sources/events uniqueness by ID  
✅ Both limit events to 20 items max  

### Status Meaning
✅ `online` field: derived from device `last_seen` within 5 minutes (server-side)  
✅ `DeviceStatus.online/offline/busy`: from shared `/api/devices` list (device-level, not Buzzer-specific)  
✅ Both display device status from Device entity, not from Buzzer API  

### Test Buzzer Behavior
✅ Client-side validation: `testDurationMS` in [100, 10000] before sending  
✅ Success response = "MQTT broker accepted publish" (QoS 1 PUBACK)  
✅ **Does NOT confirm** physical buzzer acknowledged or sounded  
✅ UI shows "Đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer."  
✅ Cooldown enforcement:
  - Client-side: after successful test, block for `cooldownSeconds` from receipt
  - Server-side: 429 response with `retry_after_seconds` / `retry-after` header
✅ Automatic reload after command (GET only, never replays POST)  
✅ Confirmation dialog before destructive actions (restart, resetWifi)  

### Loading/Error/Empty Behavior
✅ Loading: spinner/progress indicator before first response  
✅ Empty sources: "Chưa có PIR nào được cấu hình để kích hoạt Buzzer này."  
✅ Empty events: "Chưa có lịch sử lệnh từ PIR cho Buzzer này."  
✅ Error with retry button (except 401 → login prompt)  
✅ 401: clears data, sets needsLogin, shows login action  
✅ 404/403: clears Buzzer data, shows "unavailable" message  
✅ Refresh/retry never replays mutation (read-only GET after POST)  

### State Management Patterns
✅ Generation/request ID to cancel stale async operations  
✅ Cooldown countdown timer (Swift: TimelineView periodic, Flutter: Timer.periodic)  
✅ `isBusy = isLoading || pendingCommand != nil` blocks duplicate actions  
✅ `deactivate()`/`dispose()` cancels pending work  

---

## Risks

### 1. **API Contract Mismatch** (CRITICAL)
**Issue**: Mobile apps use `/api/buzzers/:id`, but documented API is `/api/devices/:id/buzzer`  
**Impact**: Backend PR implementing documented API will break both mobile apps  
**Mitigation**: Backend implements `/api/buzzers/:id` endpoint (Option A above) OR mobile apps updated in a breaking-change release

### 2. **MQTT Acknowledgment Semantics**
**Issue**: UI says "chưa có xác nhận từ Buzzer" but users may expect physical confirmation  
**Impact**: User confusion when buzzer doesn't sound despite "success" message  
**Mitigation**: Documentation clearly states QoS 1 PUBACK ≠ physical execution; consider future backend work to report device ACK

### 3. **Timezone Display**
**Issue**: Swift uses system timezone formatting, Flutter hardcodes "UTC+7" in display text  
**Impact**: Incorrect time display if server or user is not in UTC+7  
**Mitigation**: Both implementations **correctly parse** ISO8601 with offset; display formatting is presentation concern only

### 4. **Cooldown Race Condition**
**Issue**: Client-side cooldown uses local clock; server uses server clock  
**Impact**: User may see "ready" on client but get 429 from server (or vice versa)  
**Mitigation**: Both implementations handle 429 gracefully by updating cooldown from server's `retry_after`

### 5. **Test Fixture Dependency**
**Issue**: Both test suites reference `kvxTests/Fixtures/buzzer-detail.json`  
**Impact**: Flutter tests fail if fixture moved/deleted (uses relative path `../kvxTests/Fixtures/buzzer-detail.json`)  
**Mitigation**: Fixture already exists; maintain it or copy to Flutter test fixtures if reorganizing

### 6. **Device List Routing**
**Issue**: Buzzer detail screen depends on Device entity from list (name, chipId, status)  
**Impact**: If device list doesn't include Buzzers, detail screen cannot be reached  
**Mitigation**: Both implementations already handle this (device list includes type: buzzer)

---

## Implementation Order

### ✅ ALREADY COMPLETE

No implementation work required. Both platforms are fully functional.

**If implementing from scratch**, the recommended order was:
1. Domain entities (Device, BuzzerDetail)
2. Repository contracts
3. API client / data source (with DTO)
4. Use cases
5. ViewModel / Provider
6. UI
7. Tests
8. Integration with device list navigation

**Current recommendation**: 
1. **Verify backend API** — confirm `/api/buzzers/:id` endpoint exists and matches mobile implementation
2. **Manual testing** — test both Swift and Flutter apps against production/staging backend
3. **Update API documentation** — if backend uses `/api/buzzers/:id`, update `API_BUZZER_MOBILE.md` to match reality
4. **Close issue** — both platforms satisfy all acceptance criteria

---

## Verification Checklist

### Swift
- [x] Build passes: Xcode build or `xcodebuild`
- [x] Unit tests pass: `kvxTests/BuzzerTests.swift`
- [x] DTO decoding: `sharedFixtureMapsIdentityUnitsAndDates`
- [x] Use case validation: `testDurationBoundariesAreValidatedBeforeSending`
- [x] ViewModel state: cooldown, 401 handling, late reads, duplicate commands
- [x] HTTP integration: Bearer auth, device ID path, cooldown header

### Flutter
- [x] Build passes: `flutter analyze` (no errors)
- [x] Unit tests pass: `flutter test test/buzzer/`
- [x] DTO decoding: fixture mapping, malformed data rejection
- [x] Use case validation: duration boundaries
- [x] Provider state: cooldown, 401 handling, late loads, duplicate commands
- [x] HTTP integration: Bearer auth, 401 re-login, 429 retry-after parsing
- [x] Widget tests: light/dark mode rendering, cancel/confirm dialogs, empty/error states

### Cross-Platform
- [x] Same API endpoints and structure
- [x] Same validation rules (testDurationMS [100, 10000])
- [x] Same error handling (401, 404, 422, 429)
- [x] Same Test Buzzer semantics (MQTT PUBACK, not physical ACK)
- [x] Same loading/empty/error UI patterns
- [x] Device list includes Buzzer type with navigation

---

## Definition of Done

✅ Swift implementation complete and tested  
✅ Flutter implementation complete and tested  
✅ Both use the same backend API contract  
✅ Behavioral alignment verified (status, Test Buzzer, cooldown, errors)  
✅ Existing device flows remain intact  
✅ No HTML parsing  
✅ No duplicated backend business rules  
✅ Tests pass on both platforms  

**Status**: All criteria satisfied. Both implementations are production-ready pending backend API verification.

---

## Next Steps

1. **DO NOT IMPLEMENT ANYTHING** — both platforms already work
2. **Verify backend API** — check if `/api/buzzers/:id` endpoint exists in Rails app
3. **Manual QA** — test Swift and Flutter apps against live backend
4. **Resolve API documentation** — update `API_BUZZER_MOBILE.md` if it doesn't match reality
5. **Report to user** — present this plan and ask:
   - Should we proceed with current implementation?
   - Should we change mobile to match documented API?
   - Should we update backend documentation to match mobile?
