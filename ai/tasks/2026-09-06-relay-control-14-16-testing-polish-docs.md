# Task 14-16 — Testing, Polish, and Documentation

## Status

Ready to start (depends on Tasks 01-13).

## Goal

Complete the relay control feature with comprehensive testing, UI polish, accessibility improvements, and documentation.

## Scope

- Integration testing for complete user flows.
- UI polish: spacing, colors, animations, dark mode.
- Accessibility: screen reader support, contrast, text scaling.
- Documentation: API contract, architecture updates, user guide.

---

## Task 14: Integration Testing

### Purpose
Verify complete user flows work end-to-end with all layers integrated.

### Test Scenarios

#### 1. Complete Relay Control Flow

```dart
// test/integration/relay_control_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kvx_flutter/main.dart';
import 'package:kvx_flutter/data/datasources/in_memory_relay_datasource.dart';

void main() {
  testWidgets('Complete relay control flow', (tester) async {
    // Setup: Launch app with in-memory datasource
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // Step 1: Device list loads
    expect(find.text('Thiết bị'), findsOneWidget);

    // Step 2: Find and tap relay device
    final relayDevice = find.text('esp8266_11729385');
    expect(relayDevice, findsOneWidget);
    await tester.tap(relayDevice);
    await tester.pumpAndSettle();

    // Step 3: Relay detail screen opens
    expect(find.text('Kênh 1'), findsOneWidget);
    expect(find.text('Kênh 2'), findsOneWidget);

    // Step 4: Toggle relay on
    final toggleSwitch = find.byType(Switch).first;
    await tester.tap(toggleSwitch);
    await tester.pumpAndSettle();
    expect(find.text('BẬT'), findsOneWidget);

    // Step 5: Activate longlast
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.tap(find.text('KÍCH HOẠT'));
    await tester.pumpAndSettle();
    expect(find.text('Relay sẽ tự động tắt sau 5 giây'), findsOneWidget);

    // Step 6: Add reminder
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    // ... date/time picker interactions ...
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.tap(find.text('Hẹn giờ'));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm hẹn giờ'), findsOneWidget);

    // Step 7: Navigate to statistics
    await tester.tap(find.text('📊 Xem thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Thống kê Kênh 1'), findsOneWidget);

    // Step 8: Go back
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kênh 1'), findsOneWidget);
  });
}
```

#### 2. Error Handling Flow

```dart
testWidgets('Error handling shows SnackBar', (tester) async {
  // Setup datasource to fail
  final datasource = InMemoryRelayDataSource(shouldFail: true);
  
  await tester.pumpWidget(MyApp(datasource: datasource));
  await tester.pumpAndSettle();

  // Navigate to relay detail
  await tester.tap(find.text('esp8266_11729385'));
  await tester.pumpAndSettle();

  // Try to toggle relay (will fail)
  await tester.tap(find.byType(Switch).first);
  await tester.pumpAndSettle();

  // Error SnackBar appears
  expect(find.text('Không thể điều khiển relay'), findsOneWidget);
});
```

#### 3. Multi-Channel Tab Switching

```dart
testWidgets('Tab switching loads channel data', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Navigate to relay detail
  await tester.tap(find.text('esp8266_11729385'));
  await tester.pumpAndSettle();

  // Initially on Kênh 1
  expect(find.text('Kênh 1'), findsOneWidget);

  // Switch to Kênh 2
  await tester.tap(find.text('Kênh 2'));
  await tester.pumpAndSettle();

  // Verify channel 2 content loaded
  // (check for channel-specific reminders or state)
});
```

### Acceptance Criteria

- [ ] Integration tests pass on simulator/emulator
- [ ] Tests cover happy path and error scenarios
- [ ] Tests verify multi-channel behavior
- [ ] Tests verify navigation flow
- [ ] Tests verify state management across screens
- [ ] No flaky tests (run multiple times)

---

## Task 15: UI Polish and Accessibility

### A. Spacing and Layout

**Issues to fix:**
- Inconsistent padding between sections
- Card shadows too heavy
- Button sizes not uniform
- Text alignment issues

**Standards:**
```dart
// Spacing scale
const spacing4 = 4.0;
const spacing8 = 8.0;
const spacing12 = 12.0;
const spacing16 = 16.0;
const spacing20 = 20.0;
const spacing24 = 24.0;
const spacing30 = 30.0;

// Border radius
const radiusSmall = 8.0;
const radiusMedium = 12.0;
const radiusLarge = 16.0;

// Card elevation
const elevationLow = 2.0;
const elevationMedium = 4.0;
```

Apply consistently across all widgets.

---

### B. Dark Mode Support

**Checklist:**
- [ ] Use `Theme.of(context).cardColor` instead of `Colors.white`
- [ ] Use `Theme.of(context).textTheme` for text colors
- [ ] Test all screens in dark mode
- [ ] Check border colors (use `Theme.of(context).dividerColor`)
- [ ] Verify icon colors adapt to theme

**Example fixes:**
```dart
// Before
color: Colors.white,

// After
color: Theme.of(context).cardColor,

// Before
color: Colors.grey.shade600,

// After
color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
```

---

### C. Accessibility

**1. Screen Reader Support**

Add Semantics widgets:
```dart
Semantics(
  label: 'Toggle relay on or off',
  child: RelayToggleSwitch(...),
)

Semantics(
  button: true,
  label: 'Activate relay for specified duration',
  child: ElevatedButton(...),
)
```

**2. Text Scaling**

Test with large text:
```dart
// Settings > Accessibility > Larger Text
// Text should scale up to 200% without breaking layout
```

Fixes:
- Don't hardcode widget sizes (use `MediaQuery.textScaleFactor`)
- Allow buttons to grow with text
- Use flexible layouts (Expanded, Flexible)

**3. Color Contrast**

Verify WCAG AA compliance:
- Normal text: 4.5:1 contrast ratio
- Large text (18pt+): 3:1 contrast ratio
- Interactive elements: clear focus indicators

Use tools: https://webaim.org/resources/contrastchecker/

**4. Focus Indicators**

Ensure keyboard navigation works:
- Tab through all interactive elements
- Visible focus rings
- Logical tab order

---

### D. Loading States

**Improvements:**
- [ ] Shimmer effect for loading cards
- [ ] Skeleton loaders for lists
- [ ] Disable controls during loading (already done)
- [ ] Show progress for long operations

Example:
```dart
// Instead of blank space
CircularProgressIndicator()

// Use shimmer
Shimmer.fromColors(
  baseColor: Colors.grey.shade300,
  highlightColor: Colors.grey.shade100,
  child: Container(
    height: 100,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

---

### E. Animations

Add subtle animations for better UX:

**1. Toggle Switch**
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  // ... properties change based on state
)
```

**2. Reminder List**
```dart
AnimatedList(
  // Animate add/remove
)
```

**3. Screen Transitions**
```dart
Navigator.push(
  context,
  PageRouteBuilder(
    pageBuilder: (_, __, ___) => RelayDeviceDetailScreen(...),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  ),
);
```

---

### F. Error States

Improve error messages:
- [ ] Clear, actionable messages in Vietnamese
- [ ] Suggest fixes when possible
- [ ] Retry button for network errors
- [ ] Contact support option for persistent errors

Example:
```dart
// Before
"Không thể điều khiển relay"

// After
"Không thể kết nối với thiết bị. Kiểm tra kết nối mạng và thử lại."
```

---

### Acceptance Criteria (Task 15)

- [ ] Spacing consistent across all screens
- [ ] Dark mode tested and working
- [ ] Screen reader announces all elements correctly
- [ ] Text scales without breaking layout
- [ ] Color contrast meets WCAG AA
- [ ] Loading states use shimmer/skeleton
- [ ] Animations smooth (60fps)
- [ ] Error messages clear and actionable
- [ ] Manual testing on multiple devices/screen sizes

---

## Task 16: Documentation

### A. API Contract Documentation

Create `docs/api/relay-control-api.md`:

```markdown
# Relay Control API Contract

## Endpoints

### POST /api/devices/toggle_relay

Turns a relay on or off.

**Request:**
```json
{
  "device_id": "esp8266_11729385",
  "relay_index": 0,
  "is_on": true
}
```

**Response:**
```json
{
  "success": true
}
```

**Error Codes:**
- 400: Invalid parameters
- 401: Unauthorized
- 404: Device not found
- 500: Server error

### POST /api/devices/set_longlast

Activates relay for a specific duration, then auto-off.

**Request:**
```json
{
  "device_id": "esp8266_11729385",
  "relay_index": 0,
  "longlast": 300000
}
```

**Response:**
```json
{
  "success": true
}
```

... (document all 10 endpoints)
```

---

### B. Architecture Updates

Update `ai/ARCHITECTURE.md`:

```markdown
## Relay Control

Relay devices support multi-channel control with scheduling:

**Domain Layer:**
- `RelayChannel`: represents one relay (index, state)
- `RelayReminder`: scheduled activation with repeat patterns
- `RelayStatistics`: usage metrics per channel

**Use Cases:**
- `ToggleRelayUseCase`: on/off control
- `ManageRelayReminderUseCase`: CRUD for reminders
- `GetRelayStatisticsUseCase`: fetch usage data

**Presentation:**
- `RelayDeviceDetailScreen`: main control UI with tabs
- `RelayStatisticsScreen`: usage statistics
- Tab view for multi-channel devices (up to N channels)

**State Management:**
- `RelayDeviceProvider`: manages relay state, reminders, loading/error
- Reminders loaded per channel when tab switches
- Optimistic updates for toggle actions
```

---

### C. User Guide (Optional)

Create `docs/user-guide/relay-devices.md`:

```markdown
# Hướng dẫn sử dụng Thiết bị Relay

## Điều khiển Relay

### Bật/Tắt Relay
1. Mở danh sách thiết bị
2. Chọn thiết bị relay
3. Chuyển công tắc sang trạng thái mong muốn

### Kích hoạt tạm thời
Bật relay trong khoảng thời gian xác định, sau đó tự động tắt:
1. Nhập thời gian (giây hoặc phút)
2. Nhấn **KÍCH HOẠT**
3. Relay sẽ tự động tắt sau thời gian đã đặt

### Hẹn giờ
Lập lịch bật/tắt relay tự động:
1. Chọn thời gian bắt đầu
2. Nhập thời gian hoạt động
3. Chọn loại lặp lại (Không lặp, Hằng ngày, Hằng tuần, Hằng tháng)
4. Nhấn **Hẹn giờ**

### Xem thống kê
- Tổng thời gian relay đã bật
- Số lần kích hoạt
- Lần kích hoạt cuối cùng

... (more user-facing docs)
```

---

### D. Update CHANGELOG.md

```markdown
# Changelog

## [Unreleased]

### Added
- Relay control detail screen with multi-channel support
- Toggle relay on/off
- Activate relay for specific duration (longlast)
- Schedule relay with reminders (daily/weekly/monthly)
- Relay usage statistics per channel
- Device control actions (refresh, restart, reset WiFi)
- Tab view for multi-channel relay devices
- Confirmation dialogs for destructive actions

### Technical
- Domain: `RelayChannel`, `RelayReminder`, `RelayStatistics` entities
- Use Cases: 5 new use cases for relay operations
- Data: DTOs for relay API responses, in-memory and BinBlog datasources
- Presentation: 7 reusable widgets, `RelayDeviceProvider` state management
```

---

### E. Code Comments

Add doc comments for public APIs:

```dart
/// Provider for managing relay device state and operations.
///
/// Handles:
/// - Relay on/off control
/// - Duration-based activation
/// - Reminder management (CRUD)
/// - Device control (refresh, restart, reset WiFi)
/// - Loading and error states
class RelayDeviceProvider extends ChangeNotifier {
  /// Toggles a relay channel on or off.
  ///
  /// [relayIndex] is 0-based channel number.
  /// [isOn] is the desired state.
  ///
  /// Sets [isToggling] to true during the operation.
  /// On error, sets [error] with user-friendly message.
  Future<void> toggleRelay(int relayIndex, bool isOn) async { ... }
}
```

---

### Acceptance Criteria (Task 16)

- [ ] API contract documented with examples
- [ ] Architecture doc updated with relay patterns
- [ ] CHANGELOG.md updated with new features
- [ ] Key classes have doc comments
- [ ] User guide created (if needed)
- [ ] README updated with relay features (if applicable)

---

## Verification Checklist

### Manual Testing

**Device List:**
- [ ] Relay devices show correct icon
- [ ] Tapping opens relay detail screen

**Relay Detail Screen:**
- [ ] Tabs show correct channel count
- [ ] Tab switching works smoothly
- [ ] Device info header displays correctly

**Toggle Control:**
- [ ] Switch responds immediately
- [ ] Loading indicator shows during request
- [ ] State updates after success
- [ ] Error SnackBar shows on failure

**Longlast Activation:**
- [ ] Input validation works (positive integer only)
- [ ] Unit dropdown changes (Giây/Phút)
- [ ] Success message shows duration
- [ ] Button disabled during loading

**Reminder Management:**
- [ ] Date/time picker works
- [ ] Duration input validates
- [ ] Repeat type dropdown works
- [ ] Reminder appears in list after add
- [ ] Delete removes reminder
- [ ] Toggle all reminders works

**Statistics:**
- [ ] Screen loads statistics
- [ ] Data formats correctly (duration, count, datetime)
- [ ] Refresh button reloads data
- [ ] Error state shows retry option

**Device Control:**
- [ ] Refresh updates device state
- [ ] Restart shows confirmation dialog
- [ ] Reset WiFi shows confirmation dialog
- [ ] Actions trigger success messages

**Accessibility:**
- [ ] Screen reader reads all elements
- [ ] Text scales without breaking layout
- [ ] Colors have sufficient contrast
- [ ] Focus indicators visible

**Dark Mode:**
- [ ] All screens render correctly
- [ ] Text readable
- [ ] Icons visible
- [ ] Cards have appropriate colors

**Responsive:**
- [ ] Works on small phones (320x568)
- [ ] Works on tablets
- [ ] Landscape mode usable

---

## Implementation Notes

### Testing Strategy

**Priority:**
1. Integration tests (high value, catch real issues)
2. Widget tests (fast, isolated)
3. Unit tests (already done in earlier tasks)

**Coverage Goals:**
- Integration: 80% of user flows
- Widget: 90% of interactive widgets
- Unit: 100% of business logic

### Polish Priorities

**High Impact:**
- Dark mode support (widely used)
- Loading states (perceived performance)
- Error messages (usability)

**Medium Impact:**
- Animations (polish)
- Accessibility (compliance)
- Spacing consistency (professionalism)

**Low Impact:**
- Custom icons (can use default)
- Advanced animations (nice-to-have)

### Documentation Priorities

**Must Have:**
- API contract (dev reference)
- Architecture updates (maintainability)
- CHANGELOG (release notes)

**Should Have:**
- Code comments (public APIs)
- User guide (if external users)

**Nice to Have:**
- Video tutorials
- Screenshots in docs

---

## Risks / Limitations

- **Risk**: Integration tests flaky on CI
  - **Mitigation**: Use `pumpAndSettle`, avoid hardcoded delays

- **Risk**: Accessibility audit time-consuming
  - **Mitigation**: Focus on critical paths, use automated tools

- **Risk**: Documentation gets stale
  - **Mitigation**: Keep close to code, update in same PR

- **Limitation**: No automated visual regression testing
  - **Rationale**: Manual testing sufficient for MVP

---

## Out of Scope

- Automated performance testing
- Load testing API endpoints
- Internationalization (i18n) beyond Vietnamese
- Advanced animations (spring physics, etc.)
- Custom design system tokens
- Storybook/component gallery

---

## Completion Checklist

- [ ] All integration tests pass
- [ ] UI polish completed (spacing, colors, dark mode)
- [ ] Accessibility audit passed
- [ ] Documentation complete (API, architecture, changelog)
- [ ] Manual testing checklist completed
- [ ] Code review passed
- [ ] PR merged to main branch
- [ ] Feature deployed to staging/production

---

## Follow-Up Work (Future)

After MVP is stable:
- Realtime relay state updates (WebSocket)
- Push notifications for reminders
- Historical usage charts
- Relay naming/labeling
- Batch operations (control multiple relays)
- Conditional automation (if-then rules)
- Offline support with sync
- Export statistics (CSV/PDF)
