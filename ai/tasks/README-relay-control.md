# Relay Control Feature - Task Index

## Quick Navigation

**Start here**: Read this index first to understand the complete task structure.

---

## 📚 Core Documentation

| File | Purpose | Who Needs It |
|------|---------|--------------|
| [00-cross-platform-summary.md](2026-09-06-relay-control-00-cross-platform-summary.md) | High-level overview, strategy, timeline | Everyone (start here) |
| [swift-guide.md](2026-09-06-relay-control-swift-guide.md) | Swift/iOS implementation patterns | iOS developers |
| [update-checklist.md](2026-09-06-relay-control-update-checklist.md) | Task update status | Project managers |
| `../architecture/relay-control-detail-screen.md` | Original architecture decision | Architects |

---

## 🎯 Task Files (01-16)

### Foundation Layer (Domain & Application)

| Task | Title | Flutter | Swift | Status |
|------|-------|---------|-------|--------|
| [01](2026-09-06-relay-control-01-domain-entities.md) | Domain Entities | ✅ Detailed | ✅ Detailed | Ready |
| [02](2026-09-06-relay-control-02-repository-contract.md) | Repository Contract | ✅ Detailed | 📖 See Swift Guide | Ready |
| [03](2026-09-06-relay-control-03-use-cases.md) | Use Cases | ✅ Detailed | 📖 See Swift Guide | Ready |

**Estimated Time**: Foundation = 12-16 hours total (both platforms)

---

### Data Layer (DTOs & API)

| Task | Title | Flutter | Swift | Status |
|------|-------|---------|-------|--------|
| [04](2026-09-06-relay-control-04-dtos-mapping.md) | DTOs & Mapping | ✅ Detailed | 📖 See Swift Guide | Ready |
| [05](2026-09-06-relay-control-05-data-sources.md) | Data Sources (In-Memory + API) | ✅ Detailed | 📖 See Swift Guide | Ready |
| [06](2026-09-06-relay-control-06-repository-implementation.md) | Repository Implementation | ✅ Detailed | 📖 See Swift Guide | Ready |

**Estimated Time**: Data Layer = 22-32 hours total (both platforms)

---

### Presentation Layer (UI)

| Task | Title | Flutter | Swift | Status |
|------|-------|---------|-------|--------|
| [07-08](2026-09-06-relay-control-07-08-ui-widgets.md) | UI Widgets | ✅ Detailed | 📖 See Swift Guide | Ready |
| [09-13](2026-09-06-relay-control-09-13-screens-integration.md) | Screens & Integration | ✅ Detailed | 📖 See Swift Guide | Ready |

**Estimated Time**: Presentation = 34-42 hours total (both platforms)

---

### Quality & Documentation

| Task | Title | Flutter | Swift | Status |
|------|-------|---------|-------|--------|
| [14-16](2026-09-06-relay-control-14-16-testing-polish-docs.md) | Testing, Polish, Docs | ✅ Detailed | 📖 Testing patterns in Swift Guide | Ready |

**Estimated Time**: Quality = 20-24 hours total (both platforms)

---

## 🚀 Getting Started

### For Flutter Developers

1. Read [00-cross-platform-summary.md](2026-09-06-relay-control-00-cross-platform-summary.md)
2. Start with [Task 01](2026-09-06-relay-control-01-domain-entities.md) - Flutter section
3. Follow tasks 02-16 sequentially
4. Each task has:
   - ✅ Complete Dart implementation code
   - ✅ Test examples
   - ✅ Verification steps

**Your path**: Tasks 01 → 02 → 03 → 04 → 05A → 07-08 → 09-13 → 05B → 06 → 14-16

---

### For Swift/iOS Developers

1. Read [00-cross-platform-summary.md](2026-09-06-relay-control-00-cross-platform-summary.md)
2. Open [swift-guide.md](2026-09-06-relay-control-swift-guide.md) - **Your main reference**
3. Follow task numbers 01-16, but use Swift Guide for implementation details
4. Cross-reference with Flutter tasks to understand requirements

**Your path**: 
- Read Task requirements from numbered task files
- Implement using patterns from Swift Guide
- Cross-platform consistency checks at milestones

---

### For Team Leads / Architects

1. Review [00-cross-platform-summary.md](2026-09-06-relay-control-00-cross-platform-summary.md)
2. Choose implementation strategy (Sequential, Parallel, or Hybrid)
3. Assign tasks based on strategy:
   - **Sequential**: One dev does Flutter (45-60h), then Swift (45-60h)
   - **Parallel**: Two devs work simultaneously (45-60h each)
   - **Hybrid**: Foundation together (3-4 days), then split (5-7 days)
4. Track progress using [update-checklist.md](2026-09-06-relay-control-update-checklist.md)

---

## 📋 Task Dependencies

```
Foundation (Must do first):
  01 (Domain Entities) ─┐
                        ├─→ 02 (Repository Contract) ─→ 03 (Use Cases)
                        └─→ 04 (DTOs)

Data Layer (After Foundation):
  03 + 04 ─→ 05A (In-Memory) ─→ 06 (Repository Impl)
         └─→ 05B (Real API)   ─┘

Presentation (After Foundation + 05A):
  01 ─→ 07-08 (Widgets) ─→ 09-13 (Screens + Integration)
                                     │
                                     └─→ 12 (Navigation)
                                     └─→ 13 (DI Registration)

Quality (After everything):
  All previous tasks ─→ 14-16 (Testing, Polish, Docs)
```

**Critical Path**: 01 → 02 → 03 → 05A → 07-08 → 09-13 → 14

**Parallel Possible**: 04, 05B, 06 can be done alongside presentation work

---

## 🎨 Implementation Patterns

### Flutter Pattern (from task files)
```dart
// Domain
class RelayChannel { }

// Repository
abstract class DeviceRepository {
  Future<void> toggleRelay(...);
}

// Use Case
class ToggleRelayUseCase {
  Future<void> call(...) => repository.toggleRelay(...);
}

// Provider
class RelayDeviceProvider extends ChangeNotifier {
  Future<void> toggleRelay(...) async {
    await useCase(...);
    notifyListeners();
  }
}

// Widget
Consumer<RelayDeviceProvider>(
  builder: (context, provider, child) {
    return Switch(
      value: provider.isOn,
      onChanged: provider.toggleRelay,
    );
  },
)
```

### Swift Pattern (from Swift Guide)
```swift
// Domain
struct RelayChannel { }

// Repository
protocol DeviceRepository {
  func toggleRelay(...) async throws
}

// Use Case
struct ToggleRelayUseCase {
  func execute(...) async throws {
    try await repository.toggleRelay(...)
  }
}

// ViewModel
@Observable
class RelayDeviceViewModel {
  func toggleRelay(...) async {
    try await useCase.execute(...)
  }
}

// View
struct RelayToggleView: View {
  @Bindable var viewModel: ViewModel
  
  var body: some View {
    Toggle(isOn: $viewModel.isOn) {
      Text("Relay")
    }
    .onChange(of: viewModel.isOn) { _, new in
      Task { await viewModel.toggleRelay(new) }
    }
  }
}
```

---

## 📊 Progress Tracking

### Week 1 Milestone (Foundation + UI Components)
- [ ] Tasks 01-04 complete (both platforms)
- [ ] Task 05A complete (in-memory datasource)
- [ ] Tasks 07-08 complete (widgets/views)
- [ ] **Demo**: Show UI with fake data

### Week 2 Milestone (Integration + API)
- [ ] Task 05B complete (real API)
- [ ] Task 06 complete (repository)
- [ ] Tasks 09-13 complete (screens + integration)
- [ ] **Demo**: Full user flow works

### Week 3 Milestone (Quality)
- [ ] Tasks 14-16 complete
- [ ] All tests passing
- [ ] Both platforms polished
- [ ] **Release**: Production ready

---

## ⚙️ Development Commands

### Flutter

```bash
# Run app
cd kvx_flutter
flutter run

# Run tests
flutter test

# Run specific test
flutter test test/domain/entities/relay_channel_test.dart

# Build release
flutter build apk  # Android
flutter build ios  # iOS
```

### Swift

```bash
# Build
xcodebuild -project kvx.xcodeproj -scheme kvx build

# Run tests
xcodebuild test \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run on simulator
open -a Simulator
xcodebuild -project kvx.xcodeproj -scheme kvx -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Or use Xcode:
- `Cmd+R`: Build and Run
- `Cmd+U`: Run Tests
- `Cmd+B`: Build only

---

## 🐛 Common Issues

### Flutter
- **Hot reload not working**: Restart app (`r` in terminal)
- **State not updating**: Check `notifyListeners()` calls
- **Build fails**: Run `flutter clean && flutter pub get`

### Swift
- **Preview crashes**: Restart Xcode, clean build folder (`Cmd+Shift+K`)
- **"Type does not conform to protocol"**: Check all required methods implemented
- **Thread safety errors**: Add `@MainActor` to view model methods
- **Compile time slow**: Enable incremental builds, use `actor` for state

---

## 📞 Getting Help

### Task-Specific Questions
- Read the specific task file first
- Check Swift Guide for iOS patterns
- Cross-reference with temperature sensor implementation

### Architecture Questions
- See `../architecture/relay-control-detail-screen.md`
- See `ai/ARCHITECTURE.md` for general patterns

### API Questions
- See `docs/api/relay-control-api.md` (create in Task 16)
- Test with in-memory datasource first

---

## ✅ Definition of Done (Per Task)

Each task is complete when:

- [ ] Code written for both Flutter and Swift
- [ ] Unit tests passing
- [ ] No compilation errors or warnings
- [ ] Code reviewed (if team process requires)
- [ ] Acceptance criteria met (from task file)
- [ ] Manual testing successful
- [ ] Cross-platform consistency verified

---

## 📝 Notes

- **Task files focus on Flutter** with full implementation details
- **Swift Guide provides equivalent Swift patterns** for all tasks
- This approach avoids duplication and keeps docs maintainable
- Developers should read both: task requirements + platform-specific guide

---

## 🎯 Success Metrics

Track these for both platforms:

- **Task Completion Rate**: X/16 tasks done
- **Test Coverage**: Maintain >80%
- **Bug Count**: Keep low during development
- **Cross-Platform Parity**: UI behavior matches
- **Performance**: Smooth 60fps UI, API calls <500ms

---

## 🔄 Updates

| Date | Update | Author |
|------|--------|--------|
| 2026-09-06 | Initial task creation | Architect AI |
| 2026-09-06 | Added Swift implementation guide | Architect AI |
| 2026-09-06 | Created task index | Architect AI |

---

**Ready to start?** 

👉 Go to [Task 01](2026-09-06-relay-control-01-domain-entities.md) and begin!

**Need Swift reference?**

👉 Open [Swift Guide](2026-09-06-relay-control-swift-guide.md) alongside task files.

**Questions about strategy?**

👉 Review [Cross-Platform Summary](2026-09-06-relay-control-00-cross-platform-summary.md) first.
