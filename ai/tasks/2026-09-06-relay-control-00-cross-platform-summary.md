# Relay Control Feature - Cross-Platform Implementation Summary

## Overview

Implement relay control feature for **both Swift (iOS)** and **Flutter (Android/iOS)** platforms with architectural consistency.

Based on HTML reference from Rails web app for device `esp8266_11729385` with 2 relay channels.

## Platform Strategy

### Swift (iOS Native)
- **Target**: kvx/ directory
- **Framework**: SwiftUI + Combine
- **Pattern**: MVVM with Observable view models
- **Async**: async/await for networking
- **Architecture**: Clean Architecture (Domain → Application → Data → Presentation)

### Flutter (Cross-Platform)
- **Target**: kvx_flutter/ directory  
- **Framework**: Flutter + Material 3
- **Pattern**: Provider for state management
- **Async**: Future/Stream for async operations
- **Architecture**: Clean Architecture (Domain → Application → Data → Presentation)

### Consistency Goals
- Same business logic and validation rules
- Equivalent user flows and UI behavior
- Matching field names (camelCase)
- Aligned error handling approach

---

## Task Breakdown by Platform

| Task | Description | Flutter | Swift | Total Time |
|------|-------------|---------|-------|------------|
| **01** | Domain Entities | 2-3h | 2-3h | 4-6h |
| **02** | Repository Contract | 1h | 1h | 2h |
| **03** | Use Cases | 3-4h | 3-4h | 6-8h |
| **04** | DTOs & Mapping | 3-4h | 3-4h | 6-8h |
| **05A** | In-Memory DataSource | 2-3h | 2-3h | 4-6h |
| **05B** | API Integration | 4-6h | 4-6h | 8-12h |
| **06** | Repository Impl | 2-3h | 2-3h | 4-6h |
| **07-08** | UI Widgets | 7-9h | 6-8h | 13-17h |
| **09-13** | Screens & Integration | 10-12h | 10-12h | 20-24h |
| **14-16** | Testing & Polish | 10-12h | 10-12h | 20-24h |
| **Total** | | **45-60h** | **45-60h** | **90-120h** |

---

## Implementation Strategy

### Option A: Sequential (Single Developer)
1. Complete Flutter first (45-60h = ~6-8 days)
2. Port to Swift (45-60h = ~6-8 days)
3. **Total**: 12-16 days

**Pros:**
- Learn from Flutter implementation
- Refine design before porting
- Single developer can manage

**Cons:**
- iOS users wait longer
- No early feedback on both platforms

---

### Option B: Parallel (Two Developers)
- **Developer 1**: Flutter track
- **Developer 2**: Swift track
- Both work simultaneously on same task numbers
- **Total**: 6-8 days

**Pros:**
- Both platforms ready at same time
- Can share learnings during implementation
- Faster time to market

**Cons:**
- Requires coordination
- Need 2 developers

---

### Option C: Hybrid (Recommended)
**Phase 1**: Foundation (Both Platforms)
- Tasks 01-04: Domain & DTOs (both)
- **Time**: 3-4 days
- **Goal**: Shared understanding of domain

**Phase 2**: Platform Split
- **Developer 1**: Flutter Tasks 05-13
- **Developer 2**: Swift Tasks 05-13
- **Time**: 5-7 days
- **Goal**: Parallel UI development

**Phase 3**: Integration Testing
- Both test their implementations
- Cross-platform UX alignment
- **Time**: 2-3 days

**Total**: 10-14 days with 2 developers

---

## Cross-Platform Type Mapping Reference

| Concept | Dart (Flutter) | Swift | Notes |
|---------|----------------|-------|-------|
| **Time Duration** | `Duration` | `TimeInterval` (Double) | Dart: microseconds, Swift: seconds |
| **Absolute Time** | `DateTime` | `Date` | Both represent instants |
| **Optional** | `Type?` | `Type?` | Identical syntax |
| **List** | `List<T>` | `[T]` | Array in Swift |
| **Map** | `Map<K,V>` | `Dictionary<K,V>` | Similar semantics |
| **String** | `String` | `String` | Identical |
| **Integer** | `int` (64-bit) | `Int` (64-bit on 64-bit platforms) | Equivalent |
| **Boolean** | `bool` | `Bool` | Equivalent |
| **JSON Parsing** | `jsonDecode()` + DTOs | `JSONDecoder()` + Codable | Different mechanisms |
| **Async** | `Future<T>` | `async throws -> T` | Different syntax, same concept |
| **Stream** | `Stream<T>` | `AsyncSequence<T>` / Combine | Multiple approaches in Swift |

---

## Key Implementation Differences

### State Management

**Flutter:**
```dart
class RelayDeviceProvider extends ChangeNotifier {
  void toggleRelay() {
    // ... logic
    notifyListeners(); // triggers UI rebuild
  }
}
```

**Swift:**
```swift
@Observable
class RelayDeviceViewModel {
  func toggleRelay() {
    // ... logic
    // SwiftUI auto-observes @Observable
  }
}
```

---

### UI Structure

**Flutter:**
- Widgets compose into tree
- `StatelessWidget` / `StatefulWidget`
- Material Design by default
- Single codebase for iOS and Android

**Swift:**
- Views compose into hierarchy  
- `View` protocol
- iOS native look and feel
- iOS only

---

### Navigation

**Flutter:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => DetailScreen()),
);
```

**Swift:**
```swift
NavigationLink(value: device) {
  DeviceRow(device: device)
}
.navigationDestination(for: Device.self) { device in
  RelayDeviceDetailView(device: device)
}
```

---

### Dependency Injection

**Flutter:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => RelayDeviceProvider(
        toggleRelayUseCase: ToggleRelayUseCase(repository),
      ),
    ),
  ],
  child: MyApp(),
)
```

**Swift:**
```swift
@main
struct KVXApp: App {
  @State private var container = DependencyContainer()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(container)
    }
  }
}
```

---

## Shared Validation Rules

Must be identical across platforms:

1. **Relay Index**: Must be >= 0
2. **Duration**: Must be > 0 (positive)
3. **Start Time**: Accept past times (with warning), reject far future
4. **Device ID**: Non-empty string
5. **Reminder Repeat Types**: `none`, `daily`, `weekly`, `monthly`

---

## API Contract (Both Platforms)

All 10 endpoints must be implemented identically:

1. `POST /api/devices/toggle_relay`
2. `POST /api/devices/set_longlast`
3. `GET /api/devices/reminders`
4. `POST /api/devices/add_reminder`
5. `DELETE /api/devices/remove_reminder`
6. `POST /api/devices/toggle_reminders`
7. `GET /api/devices/relay_statistics`
8. `POST /api/devices/refresh_device`
9. `POST /api/devices/restart`
10. `POST /api/devices/reset_wifi`

**Authentication**: Bearer token from login endpoint
**Base URL**: `https://khuonvien.vn`

---

## Testing Parity

Both platforms must test:

### Unit Tests
- Entity creation and validation
- Use case logic
- DTO mapping (JSON ↔ Domain)
- Repository error handling

### Integration Tests
- Complete user flows
- Error scenarios
- Multi-channel tab switching
- Navigation flows

### UI Tests (Critical Paths)
- Toggle relay on/off
- Add/remove reminders
- Navigate to statistics
- Device control actions

---

## User Flow Parity

Exact same flows on both platforms:

1. **Device List** → Tap relay device → **Relay Detail**
2. **Relay Detail** → Toggle switch → Relay state changes
3. **Relay Detail** → Activate for duration → Success message
4. **Relay Detail** → Add reminder → Appears in list
5. **Relay Detail** → Tap statistics → **Statistics Screen**
6. **Statistics Screen** → Back → **Relay Detail**
7. **Relay Detail** → Restart device → Confirmation → Action

---

## Documentation Requirements

Must document for both platforms:

1. **API Contract**: Shared across platforms
2. **Architecture Decisions**: Platform-specific patterns
3. **Setup Instructions**: Per platform
4. **User Guide**: Platform-agnostic (same features)
5. **CHANGELOG**: Mention both platforms

---

## Definition of Done

Feature is complete when:

- [ ] All 16 tasks completed for **both** Swift and Flutter
- [ ] Unit tests pass on both platforms
- [ ] Integration tests pass on both platforms
- [ ] Manual testing checklist completed on both platforms
- [ ] UI looks consistent (within platform conventions)
- [ ] User flows behave identically
- [ ] Dark mode works on both platforms
- [ ] Accessibility tested on both platforms
- [ ] Documentation complete
- [ ] Code reviewed
- [ ] Deployed to staging/production

---

## Priority if Time Constrained

If you need to ship faster, prioritize:

### Must Have (MVP)
- Tasks 01-03: Domain, contracts, use cases
- Task 05A: In-memory datasource (for demo)
- Task 07-08: Core widgets (toggle, forms)
- Task 10: Main detail screen
- Basic error handling

### Should Have
- Task 05B: Real API integration
- Task 11: Statistics screen
- Task 06: Full repository implementation
- Comprehensive testing

### Nice to Have
- Advanced animations
- Custom icons
- Detailed statistics charts
- Push notifications

---

## Risk Mitigation

### Platform-Specific Risks

**Flutter:**
- Hot reload state management issues → Restart app during testing
- Platform channel communication → Use in-memory first

**Swift:**
- Xcode build issues → Clean build folder frequently
- SwiftUI preview crashes → Test on simulator

### Shared Risks

**API Contract Mismatch:**
- Mitigation: Start with in-memory datasource
- Test real API early and often
- Document all deviations

**Timezone Bugs:**
- Mitigation: Always use UTC in domain/API
- Convert to local time only in presentation
- Test across multiple timezones

---

## Success Metrics

Track for both platforms:

- **Development Velocity**: Tasks completed per day
- **Bug Rate**: Bugs found per platform
- **Test Coverage**: Maintain >80% on both
- **Performance**: App launch time, screen transitions
- **User Adoption**: Downloads/usage after launch

---

## Next Steps

1. **Review this summary** with team
2. **Assign developers** to platforms (Option B or C)
3. **Start Task 01** on both platforms
4. **Daily sync** if doing parallel development
5. **Weekly demos** to stakeholders

---

## Questions to Resolve

Before starting:
- [ ] Which implementation strategy? (A, B, or C)
- [ ] Who implements which platform?
- [ ] When is the target launch date?
- [ ] Is real backend API ready for testing?
- [ ] Do we have test devices (iOS + Android)?

---

**Created**: 2026-09-06  
**Last Updated**: 2026-09-06  
**Status**: Ready to Start
