# Relay Control - Swift/iOS Implementation Guide

## Overview

This guide provides Swift/iOS specific implementation details for the Relay Control feature. It complements the main task files (which focus on Flutter) with Swift patterns, code examples, and iOS-specific considerations.

**Use this guide alongside**: Tasks 01-16 in `ai/tasks/2026-09-06-relay-control-*.md`

---

## Swift Project Structure

```
kvx/
├── Models/                    # Domain entities (Task 01)
│   ├── RelayChannel.swift
│   ├── RelayReminder.swift
│   ├── RelayStatistics.swift
│   └── ReminderRepeatType.swift
├── Domain/
│   ├── Repositories/         # Repository protocols (Task 02)
│   │   └── DeviceRepository.swift
│   └── UseCases/             # Use cases (Task 03)
│       ├── ToggleRelayUseCase.swift
│       ├── ActivateRelayForDurationUseCase.swift
│       ├── ManageRelayReminderUseCase.swift
│       ├── GetRelayStatisticsUseCase.swift
│       └── ControlDeviceUseCase.swift
├── Data/
│   ├── DTOs/                 # Codable structs (Task 04)
│   │   ├── BinblogRelayChannelDTO.swift
│   │   ├── BinblogRelayReminderDTO.swift
│   │   └── BinblogRelayStatisticsDTO.swift
│   ├── DataSources/          # API clients (Task 05)
│   │   ├── InMemoryRelayDataSource.swift
│   │   └── BinblogDeviceDataSource.swift (extend)
│   └── Repositories/         # Repository impl (Task 06)
│       └── DeviceRepositoryImpl.swift
├── Views/                    # SwiftUI views (Tasks 07-11)
│   ├── RelayDeviceDetailView.swift
│   ├── RelayStatisticsView.swift
│   └── Components/
│       ├── RelayToggleSwitch.swift
│       ├── RelayLonglastForm.swift
│       ├── RelayReminderForm.swift
│       ├── RelayReminderList.swift
│       ├── DeviceInfoHeader.swift
│       └── DeviceControlFooter.swift
└── ViewModels/               # View models (Task 09)
    └── RelayDeviceViewModel.swift
```

---

## Task 01: Domain Entities (Swift)

### RelayChannel.swift

```swift
struct RelayChannel: Equatable, Hashable, Identifiable {
    let id: Int  // Use index as ID for SwiftUI
    let index: Int
    let isOn: Bool
    let label: String?
    
    init(index: Int, isOn: Bool, label: String? = nil) {
        self.id = index
        self.index = index
        self.isOn = isOn
        self.label = label
    }
}
```

### ReminderRepeatType.swift

```swift
enum ReminderRepeatType: String, CaseIterable, Codable {
    case none
    case daily
    case weekly
    case monthly
    
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

### RelayReminder.swift

```swift
import Foundation

struct RelayReminder: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let deviceId: String
    let relayIndex: Int
    let startTime: Date
    let duration: TimeInterval  // seconds
    let repeatType: ReminderRepeatType
    let isActive: Bool
    
    init(
        id: String = UUID().uuidString,
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
}
```

### RelayStatistics.swift

```swift
import Foundation

struct RelayStatistics: Equatable, Hashable, Codable {
    let deviceId: String
    let relayIndex: Int
    let totalOnTime: TimeInterval
    let activationCount: Int
    let lastActivated: Date?
}
```

### Device Extension (Models/Device.swift)

```swift
struct Device: Identifiable, Equatable, Hashable, Codable {
    // ... existing fields
    
    // Relay-specific (optional for non-relay devices)
    let relayCount: Int?
    let relayChannels: [RelayChannel]?
    let firmwareVersion: String?
    let appVersion: String?
    let lastConnected: Date?
}
```

---

## Task 02: Repository Protocol (Swift)

### DeviceRepository.swift

```swift
import Foundation

protocol DeviceRepository {
    // Existing methods
    func getDevices() async throws -> [Device]
    func addDevice(_ device: Device) async throws
    func updateDevice(_ device: Device) async throws
    func deleteDevice(id: String) async throws
    
    // Relay control
    func toggleRelay(deviceId: String, relayIndex: Int, isOn: Bool) async throws
    func activateRelayForDuration(deviceId: String, relayIndex: Int, duration: TimeInterval) async throws
    
    // Reminder management
    func getReminders(deviceId: String, relayIndex: Int) async throws -> [RelayReminder]
    func addReminder(_ reminder: RelayReminder) async throws -> RelayReminder
    func removeReminder(reminderId: String) async throws
    func toggleReminders(deviceId: String, relayIndex: Int, isActive: Bool) async throws
    
    // Statistics
    func getRelayStatistics(deviceId: String, relayIndex: Int) async throws -> RelayStatistics
    
    // Device control
    func refreshDevice(deviceId: String) async throws -> Device
    func restartDevice(deviceId: String) async throws
    func resetWifi(deviceId: String) async throws
}
```

**Key Differences from Dart:**
- `async throws` instead of `Future<T>`
- No named parameters in protocol (can use in implementation)
- Protocol conformance instead of abstract class

---

## Task 03: Use Cases (Swift)

### ToggleRelayUseCase.swift

```swift
struct ToggleRelayUseCase {
    private let repository: DeviceRepository
    
    init(repository: DeviceRepository) {
        self.repository = repository
    }
    
    func execute(deviceId: String, relayIndex: Int, isOn: Bool) async throws {
        try await repository.toggleRelay(
            deviceId: deviceId,
            relayIndex: relayIndex,
            isOn: isOn
        )
    }
}
```

### ActivateRelayForDurationUseCase.swift

```swift
struct ActivateRelayForDurationUseCase {
    private let repository: DeviceRepository
    
    init(repository: DeviceRepository) {
        self.repository = repository
    }
    
    func execute(deviceId: String, relayIndex: Int, duration: TimeInterval) async throws {
        guard duration > 0 else {
            throw ValidationError.invalidDuration
        }
        
        try await repository.activateRelayForDuration(
            deviceId: deviceId,
            relayIndex: relayIndex,
            duration: duration
        )
    }
}

enum ValidationError: LocalizedError {
    case invalidDuration
    
    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Duration must be positive"
        }
    }
}
```

### ManageRelayReminderUseCase.swift

```swift
struct ManageRelayReminderUseCase {
    private let repository: DeviceRepository
    
    init(repository: DeviceRepository) {
        self.repository = repository
    }
    
    func getReminders(deviceId: String, relayIndex: Int) async throws -> [RelayReminder] {
        try await repository.getReminders(deviceId: deviceId, relayIndex: relayIndex)
    }
    
    func addReminder(_ reminder: RelayReminder) async throws -> RelayReminder {
        try await repository.addReminder(reminder)
    }
    
    func removeReminder(reminderId: String) async throws {
        try await repository.removeReminder(reminderId: reminderId)
    }
    
    func toggleReminders(deviceId: String, relayIndex: Int, isActive: Bool) async throws {
        try await repository.toggleReminders(
            deviceId: deviceId,
            relayIndex: relayIndex,
            isActive: isActive
        )
    }
}
```

**Pattern Notes:**
- Use `struct` for stateless use cases
- `async throws` for error propagation
- Multiple related methods in one use case (like Flutter)

---

## Task 04: DTOs (Swift)

### BinblogRelayReminderDTO.swift

```swift
import Foundation

struct BinblogRelayReminderDTO: Codable {
    let id: String
    let deviceId: String
    let relayIndex: Int
    let startTime: String  // ISO 8601
    let duration: Int      // milliseconds
    let repeatType: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case relayIndex = "relay_index"
        case startTime = "start_time"
        case duration
        case repeatType = "repeat_type"
        case isActive = "is_active"
    }
    
    // DTO → Domain
    func toDomain() throws -> RelayReminder {
        guard let date = ISO8601DateFormatter().date(from: startTime) else {
            throw DTOMappingError.invalidDateFormat
        }
        
        guard let type = ReminderRepeatType(rawValue: repeatType) else {
            throw DTOMappingError.unknownRepeatType(repeatType)
        }
        
        let durationInSeconds = TimeInterval(duration) / 1000.0
        
        return RelayReminder(
            id: id,
            deviceId: deviceId,
            relayIndex: relayIndex,
            startTime: date,
            duration: durationInSeconds,
            repeatType: type,
            isActive: isActive
        )
    }
    
    // Domain → DTO
    static func fromDomain(_ reminder: RelayReminder) -> BinblogRelayReminderDTO {
        BinblogRelayReminderDTO(
            id: reminder.id,
            deviceId: reminder.deviceId,
            relayIndex: reminder.relayIndex,
            startTime: ISO8601DateFormatter().string(from: reminder.startTime),
            duration: Int(reminder.duration * 1000),
            repeatType: reminder.repeatType.rawValue,
            isActive: reminder.isActive
        )
    }
}

enum DTOMappingError: LocalizedError {
    case invalidDateFormat
    case unknownRepeatType(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "Invalid date format in API response"
        case .unknownRepeatType(let type):
            return "Unknown repeat type: \(type)"
        }
    }
}
```

**Key Differences from Dart:**
- `Codable` protocol (automatic JSON encoding/decoding)
- `CodingKeys` enum for snake_case ↔ camelCase mapping
- `throws` in `toDomain()` for error handling
- ISO8601DateFormatter for date parsing

---

## Task 05: Data Sources (Swift)

### InMemoryRelayDataSource.swift

```swift
import Foundation

actor InMemoryRelayDataSource: DeviceRepository {
    private var relayStates: [String: [Int: Bool]] = [:]
    private var reminders: [String: [RelayReminder]] = []
    private var statistics: [String: [Int: RelayStatistics]] = [:]
    
    private let delay: TimeInterval
    private let shouldFail: Bool
    
    init(delay: TimeInterval = 0.3, shouldFail: Bool = false) {
        self.delay = delay
        self.shouldFail = shouldFail
        
        // Initialize demo data
        setupDemoData()
    }
    
    private func setupDemoData() {
        // Demo device
        relayStates["esp8266_11729385"] = [0: false, 1: false]
        
        // Demo reminders
        reminders["esp8266_11729385"] = [
            RelayReminder(
                id: "reminder-1",
                deviceId: "esp8266_11729385",
                relayIndex: 0,
                startTime: Date(),
                duration: 300,
                repeatType: .daily,
                isActive: true
            )
        ]
    }
    
    private func simulateDelay() async throws {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldFail {
            throw NetworkError.simulatedFailure
        }
    }
    
    func toggleRelay(deviceId: String, relayIndex: Int, isOn: Bool) async throws {
        try await simulateDelay()
        
        if relayStates[deviceId] == nil {
            relayStates[deviceId] = [:]
        }
        relayStates[deviceId]?[relayIndex] = isOn
        
        print("[InMemory] Relay \(deviceId):\(relayIndex) → \(isOn ? "ON" : "OFF")")
    }
    
    func activateRelayForDuration(deviceId: String, relayIndex: Int, duration: TimeInterval) async throws {
        try await simulateDelay()
        
        // Turn on
        if relayStates[deviceId] == nil {
            relayStates[deviceId] = [:]
        }
        relayStates[deviceId]?[relayIndex] = true
        
        print("[InMemory] Relay \(deviceId):\(relayIndex) activated for \(duration)s")
        
        // Auto-off after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await self.setRelayState(deviceId: deviceId, relayIndex: relayIndex, isOn: false)
        }
    }
    
    private func setRelayState(deviceId: String, relayIndex: Int, isOn: Bool) {
        relayStates[deviceId]?[relayIndex] = isOn
        print("[InMemory] Relay \(deviceId):\(relayIndex) auto-off")
    }
    
    func getReminders(deviceId: String, relayIndex: Int) async throws -> [RelayReminder] {
        try await simulateDelay()
        
        return reminders[deviceId]?.filter { $0.relayIndex == relayIndex } ?? []
    }
    
    func addReminder(_ reminder: RelayReminder) async throws -> RelayReminder {
        try await simulateDelay()
        
        if reminders[reminder.deviceId] == nil {
            reminders[reminder.deviceId] = []
        }
        reminders[reminder.deviceId]?.append(reminder)
        
        print("[InMemory] Added reminder \(reminder.id)")
        return reminder
    }
    
    // ... implement other methods
}

enum NetworkError: LocalizedError {
    case simulatedFailure
    
    var errorDescription: String? {
        "Simulated network failure"
    }
}
```

**Swift-Specific Notes:**
- `actor` for thread-safe state management
- `Task.sleep` for async delays
- Private helper functions for internal logic

---

## Task 06: BinBlog API DataSource (Swift)

### BinblogDeviceDataSource.swift (extend)

```swift
import Foundation

class BinblogDeviceDataSource: DeviceRepository {
    private let baseURL = URL(string: "https://khuonvien.vn")!
    private let username: String
    private let password: String
    private let session: URLSession
    
    private var cachedToken: String?
    private var tokenExpiry: Date?
    
    init(username: String, password: String, session: URLSession = .shared) {
        self.username = username
        self.password = password
        self.session = session
    }
    
    private func getAuthToken() async throws -> String {
        // Check cache
        if let token = cachedToken,
           let expiry = tokenExpiry,
           Date() < expiry {
            return token
        }
        
        // Login
        let loginURL = baseURL.appendingPathComponent("/api/login")
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginBody = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(loginBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.authenticationFailed
        }
        
        struct LoginResponse: Codable {
            let token: String
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        // Cache token
        cachedToken = loginResponse.token
        tokenExpiry = Date().addingTimeInterval(3600) // 1 hour
        
        return loginResponse.token
    }
    
    func toggleRelay(deviceId: String, relayIndex: Int, isOn: Bool) async throws {
        let token = try await getAuthToken()
        
        let url = baseURL.appendingPathComponent("/api/devices/toggle_relay")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "device_id": deviceId,
            "relay_index": relayIndex,
            "is_on": isOn
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed("Không thể điều khiển relay")
        }
    }
    
    func getReminders(deviceId: String, relayIndex: Int) async throws -> [RelayReminder] {
        let token = try await getAuthToken()
        
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/devices/reminders"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "chip_id", value: deviceId),
            URLQueryItem(name: "relay_index", value: "\(relayIndex)")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed("Không lấy được danh sách hẹn giờ")
        }
        
        struct RemindersResponse: Codable {
            let reminders: [BinblogRelayReminderDTO]
        }
        
        let remindersResponse = try JSONDecoder().decode(RemindersResponse.self, from: data)
        return try remindersResponse.reminders.map { try $0.toDomain() }
    }
    
    // ... implement other methods
}

enum APIError: LocalizedError {
    case authenticationFailed
    case requestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Đăng nhập thất bại"
        case .requestFailed(let message):
            return message
        }
    }
}
```

**Swift Networking Notes:**
- `URLSession` for HTTP requests
- `async/await` for async networking (iOS 15+)
- `Codable` for automatic JSON parsing
- Proper error handling with `throws`

---

## Task 09: View Model (Swift)

### RelayDeviceViewModel.swift

```swift
import Foundation
import Observation

@Observable
class RelayDeviceViewModel {
    private let toggleRelayUseCase: ToggleRelayUseCase
    private let activateForDurationUseCase: ActivateRelayForDurationUseCase
    private let manageReminderUseCase: ManageRelayReminderUseCase
    private let getStatisticsUseCase: GetRelayStatisticsUseCase
    private let controlDeviceUseCase: ControlDeviceUseCase
    
    // State
    var device: Device?
    var remindersByChannel: [Int: [RelayReminder]] = [:]
    var remindersActiveByChannel: [Int: Bool] = [:]
    var selectedRelayIndex = 0
    var isLoading = false
    var isToggling = false
    var isActivating = false
    var isManagingReminders = false
    var error: String?
    
    init(
        toggleRelayUseCase: ToggleRelayUseCase,
        activateForDurationUseCase: ActivateRelayForDurationUseCase,
        manageReminderUseCase: ManageRelayReminderUseCase,
        getStatisticsUseCase: GetRelayStatisticsUseCase,
        controlDeviceUseCase: ControlDeviceUseCase
    ) {
        self.toggleRelayUseCase = toggleRelayUseCase
        self.activateForDurationUseCase = activateForDurationUseCase
        self.manageReminderUseCase = manageReminderUseCase
        self.getStatisticsUseCase = getStatisticsUseCase
        self.controlDeviceUseCase = controlDeviceUseCase
    }
    
    var currentReminders: [RelayReminder] {
        remindersByChannel[selectedRelayIndex] ?? []
    }
    
    var areRemindersActive: Bool {
        remindersActiveByChannel[selectedRelayIndex] ?? true
    }
    
    func setDevice(_ device: Device) {
        self.device = device
        self.selectedRelayIndex = 0
        self.error = nil
    }
    
    func selectRelayChannel(_ index: Int) {
        selectedRelayIndex = index
        error = nil
    }
    
    @MainActor
    func toggleRelay(relayIndex: Int, isOn: Bool) async {
        guard let device = device else { return }
        
        isToggling = true
        error = nil
        
        do {
            try await toggleRelayUseCase.execute(
                deviceId: device.id,
                relayIndex: relayIndex,
                isOn: isOn
            )
            
            // Update local state optimistically
            if var channels = device.relayChannels {
                if let index = channels.firstIndex(where: { $0.index == relayIndex }) {
                    channels[index] = RelayChannel(
                        index: relayIndex,
                        isOn: isOn,
                        label: channels[index].label
                    )
                    self.device = Device(
                        id: device.id,
                        name: device.name,
                        type: device.type,
                        status: device.status,
                        relayCount: device.relayCount,
                        relayChannels: channels,
                        firmwareVersion: device.firmwareVersion,
                        appVersion: device.appVersion,
                        lastConnected: device.lastConnected
                    )
                }
            }
        } catch {
            self.error = "Không thể điều khiển relay: \(error.localizedDescription)"
        }
        
        isToggling = false
    }
    
    @MainActor
    func activateForDuration(relayIndex: Int, duration: TimeInterval) async {
        guard let device = device else { return }
        
        isActivating = true
        error = nil
        
        do {
            try await activateForDurationUseCase.execute(
                deviceId: device.id,
                relayIndex: relayIndex,
                duration: duration
            )
        } catch {
            self.error = "Không thể kích hoạt relay: \(error.localizedDescription)"
        }
        
        isActivating = false
    }
    
    @MainActor
    func loadReminders(relayIndex: Int) async {
        guard let device = device else { return }
        
        isLoading = true
        error = nil
        
        do {
            let reminders = try await manageReminderUseCase.getReminders(
                deviceId: device.id,
                relayIndex: relayIndex
            )
            remindersByChannel[relayIndex] = reminders
            remindersActiveByChannel[relayIndex] = reminders.contains { $0.isActive }
        } catch {
            self.error = "Không thể tải danh sách hẹn giờ: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // ... other methods
}
```

**SwiftUI State Management:**
- `@Observable` macro (iOS 17+) for automatic view updates
- `@MainActor` for UI updates on main thread
- Value types (`struct`) for immutable state updates
- No manual `notifyListeners()` needed

---

## Task 10: SwiftUI Views

### RelayDeviceDetailView.swift

```swift
import SwiftUI

struct RelayDeviceDetailView: View {
    let device: Device
    @State private var viewModel: RelayDeviceViewModel
    @State private var selectedTab = 0
    
    init(device: Device, viewModel: RelayDeviceViewModel) {
        self.device = device
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(0..<(device.relayCount ?? 2), id: \.self) { index in
                RelayChannelView(
                    device: device,
                    relayIndex: index,
                    viewModel: viewModel
                )
                .tabItem {
                    Text("Kênh \(index + 1)")
                }
                .tag(index)
            }
        }
        .navigationTitle(device.name)
        .task {
            viewModel.setDevice(device)
            await viewModel.loadReminders(selectedTab)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            viewModel.selectRelayChannel(newValue)
            Task {
                await viewModel.loadReminders(newValue)
            }
        }
        .alert("Lỗi", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

struct RelayChannelView: View {
    let device: Device
    let relayIndex: Int
    @Bindable var viewModel: RelayDeviceViewModel
    
    var relayChannel: RelayChannel? {
        device.relayChannels?.first { $0.index == relayIndex }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Device info header
                DeviceInfoHeader(device: device)
                
                // Toggle switch
                RelayToggleSwitch(
                    isOn: relayChannel?.isOn ?? false,
                    isLoading: viewModel.isToggling
                ) { isOn in
                    Task {
                        await viewModel.toggleRelay(relayIndex: relayIndex, isOn: isOn)
                    }
                }
                
                // Longlast form
                RelayLonglastForm(
                    isLoading: viewModel.isActivating
                ) { duration in
                    Task {
                        await viewModel.activateForDuration(
                            relayIndex: relayIndex,
                            duration: duration
                        )
                    }
                }
                
                // Statistics button
                NavigationLink(
                    destination: RelayStatisticsView(
                        deviceId: device.id,
                        relayIndex: relayIndex
                    )
                ) {
                    Label("Xem thống kê", systemImage: "chart.bar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                // Reminder form
                RelayReminderForm { formData in
                    let reminder = RelayReminder(
                        deviceId: device.id,
                        relayIndex: relayIndex,
                        startTime: formData.startTime,
                        duration: formData.duration,
                        repeatType: formData.repeatType
                    )
                    Task {
                        await viewModel.addReminder(reminder)
                    }
                }
                
                // Reminder list
                RelayReminderList(
                    reminders: viewModel.currentReminders,
                    areRemindersActive: viewModel.areRemindersActive,
                    onToggleAll: { isActive in
                        Task {
                            await viewModel.toggleReminders(
                                relayIndex: relayIndex,
                                isActive: isActive
                            )
                        }
                    },
                    onDelete: { reminderId in
                        Task {
                            await viewModel.removeReminder(
                                reminderId: reminderId,
                                relayIndex: relayIndex
                            )
                        }
                    }
                )
                
                // Device control footer
                DeviceControlFooter(
                    deviceId: device.id,
                    firmwareVersion: device.firmwareVersion,
                    appVersion: device.appVersion,
                    onRefresh: {
                        Task { await viewModel.refreshDevice() }
                    },
                    onRestart: {
                        Task { await viewModel.restartDevice() }
                    },
                    onResetWifi: {
                        Task { await viewModel.resetWifi() }
                    }
                )
            }
            .padding()
        }
    }
}
```

**SwiftUI Patterns:**
- Declarative UI with `View` protocol
- `@State` and `@Bindable` for reactive state
- `.task` modifier for async initialization
- `.onChange` for side effects
- `NavigationLink` for navigation

---

## Key Differences: Swift vs Flutter

### 1. State Management

**Flutter (Provider):**
```dart
ChangeNotifierProvider(
  create: (_) => RelayDeviceProvider(...),
  child: Consumer<RelayDeviceProvider>(
    builder: (context, provider, child) {
      return Text(provider.device.name);
    },
  ),
)
```

**Swift (@Observable):**
```swift
@Observable class ViewModel { }

struct MyView: View {
  let viewModel: ViewModel
  
  var body: some View {
    Text(viewModel.device.name)  // Auto-updates
  }
}
```

### 2. Async Operations

**Flutter:**
```dart
Future<void> loadData() async {
  try {
    final data = await repository.getData();
  } catch (e) {
    // handle error
  }
}
```

**Swift:**
```swift
func loadData() async {
  do {
    let data = try await repository.getData()
  } catch {
    // handle error
  }
}
```

### 3. Collections

**Flutter:**
```dart
List<String> items = [];
Map<String, int> dict = {};
```

**Swift:**
```swift
var items: [String] = []
var dict: [String: Int] = [:]
```

### 4. Optionals

**Flutter:**
```dart
String? name;
final value = name ?? "default";
```

**Swift:**
```swift
var name: String?
let value = name ?? "default"
```

---

## Testing in Swift

### Unit Test Example

```swift
import XCTest
@testable import kvx

final class RelayReminderTests: XCTestCase {
    func testReminderCreation() {
        let reminder = RelayReminder(
            deviceId: "device-1",
            relayIndex: 0,
            startTime: Date(),
            duration: 300,
            repeatType: .daily
        )
        
        XCTAssertEqual(reminder.relayIndex, 0)
        XCTAssertEqual(reminder.duration, 300)
        XCTAssertEqual(reminder.repeatType, .daily)
        XCTAssertTrue(reminder.isActive)
    }
    
    func testDurationValidation() {
        XCTAssertThrowsError(
            try RelayReminder(
                deviceId: "device-1",
                relayIndex: 0,
                startTime: Date(),
                duration: -1,
                repeatType: .daily
            )
        )
    }
}
```

### SwiftUI Preview

```swift
#Preview {
    NavigationStack {
        RelayDeviceDetailView(
            device: .sampleRelayDevice,
            viewModel: .preview
        )
    }
}

extension Device {
    static var sampleRelayDevice: Device {
        Device(
            id: "esp8266_11729385",
            name: "Relay Device",
            type: .switchDevice,
            status: .online,
            relayCount: 2,
            relayChannels: [
                RelayChannel(index: 0, isOn: false),
                RelayChannel(index: 1, isOn: true)
            ]
        )
    }
}

extension RelayDeviceViewModel {
    static var preview: RelayDeviceViewModel {
        let mockRepo = MockDeviceRepository()
        return RelayDeviceViewModel(
            toggleRelayUseCase: ToggleRelayUseCase(repository: mockRepo),
            // ... other use cases
        )
    }
}
```

---

## Dependency Injection (Swift)

### Using Environment

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

struct DependencyContainer {
    let repository: DeviceRepository
    
    init() {
        // Use in-memory for development
        self.repository = InMemoryRelayDataSource()
        
        // Or use real API
        // self.repository = BinblogDeviceDataSource(
        //     username: ProcessInfo.processInfo.environment["BINBLOG_USERNAME"]!,
        //     password: ProcessInfo.processInfo.environment["BINBLOG_PASSWORD"]!
        // )
    }
}

// In views
struct SomeView: View {
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        // Use container.repository
    }
}
```

---

## Build and Run

### Xcode

1. Open `kvx.xcodeproj`
2. Select iPhone simulator
3. `Cmd+R` to build and run

### Command Line

```bash
xcodebuild \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

### Run Tests

```bash
xcodebuild test \
  -project kvx.xcodeproj \
  -scheme kvx \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

---

## Common Pitfalls

### 1. Thread Safety
❌ **Wrong**: Mutating state from background thread
```swift
Task {
  let data = try await repository.getData()
  self.data = data  // Crash if not on main thread
}
```

✅ **Correct**: Use `@MainActor`
```swift
@MainActor
func loadData() async {
  let data = try await repository.getData()
  self.data = data
}
```

### 2. Memory Leaks
❌ **Wrong**: Strong reference cycle
```swift
viewModel.onComplete = {
  self.dismiss()  // Captures self strongly
}
```

✅ **Correct**: Weak self
```swift
viewModel.onComplete = { [weak self] in
  self?.dismiss()
}
```

### 3. Date/Time Conversion
❌ **Wrong**: Using local time for API
```swift
let date = Date()  // Current time in local timezone
```

✅ **Correct**: Use UTC explicitly
```swift
ISO8601DateFormatter().string(from: date)  // Always UTC
```

---

## Additional Resources

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Observation Framework](https://developer.apple.com/documentation/observation)
- [URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Codable](https://developer.apple.com/documentation/swift/codable)

---

**Last Updated**: 2026-09-06  
**Maintained by**: Development Team
