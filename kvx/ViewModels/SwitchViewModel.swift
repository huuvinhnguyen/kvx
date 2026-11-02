import Foundation
import Observation

@MainActor @Observable
final class SwitchViewModel {
    private(set) var detail: SwitchDetail?
    private(set) var selectedRelay: Int?
    private(set) var reminders: [SwitchReminder] = []
    private(set) var statistics: SwitchStatistics?
    private(set) var nextAfterID: String?
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var isBusy = false
    private(set) var readReady = false
    var uncertain: Bool { useCases.continuity.uncertain(deviceID) }
    var commandInFlight: Bool { useCases.continuity.busy(deviceID) }
    private let deviceID: String
    private let useCases: SwitchUseCases
    private var generation = 0
    private var active = true
    var canCommand: Bool { active && !isBusy && !commandInFlight && readReady && !uncertain && detail != nil }
    init(deviceID: String, useCases: SwitchUseCases) { self.deviceID = deviceID; self.useCases = useCases }
    func activate() async { active = true; await load() }
    func deactivate() { active = false; generation += 1; isBusy = false; readReady = false }
    private func current(_ g: Int) -> Bool { active && generation == g && !Task.isCancelled }
    func load() async {
        guard active, !isBusy else { return }
        generation += 1; let g = generation
        isBusy = true; readReady = false; errorMessage = nil
        defer { if active && generation == g { isBusy = false } }
        do {
            let value = try await useCases.detail(deviceID)
            guard current(g) else { return }
            detail = value
            if !value.relays.contains(where: { $0.index == selectedRelay }) { selectedRelay = value.relays.first?.index }
            if let relay = selectedRelay {
                let page = try await useCases.reminders(deviceID, relay: relay)
                let stats = value.capabilities.statistics ? try await useCases.statistics(deviceID, relay: relay) : nil
                guard current(g) else { return }
                reminders = page.reminders; nextAfterID = page.nextAfterId; statistics = stats
            } else { reminders = []; nextAfterID = nil; statistics = nil }
            readReady = true
        } catch { if current(g) { errorMessage = error.localizedDescription } }
    }
    func selectRelay(_ relay: Int) async {
        guard active, !isBusy, detail?.relays.contains(where: { $0.index == relay }) == true else { return }
        selectedRelay = relay; reminders = []; statistics = nil; nextAfterID = nil
        await load()
    }
    func moreReminders() async {
        guard active, !isBusy, readReady, let cursor = nextAfterID, let relay = selectedRelay else { return }
        generation += 1; let g = generation; isBusy = true; errorMessage = nil
        defer { if active && generation == g { isBusy = false } }
        do {
            let page = try await useCases.reminders(deviceID, relay: relay, afterID: cursor)
            guard current(g) else { return }
            reminders += page.reminders; nextAfterID = page.nextAfterId
        } catch { if current(g) { errorMessage = error.localizedDescription } }
    }
    func acknowledgePhysicalCheck() {
        guard active, readReady, !isBusy, !commandInFlight else { return }
        useCases.continuity.reconcile(deviceID); notice = "Đã xác nhận kiểm tra thiết bị. Lệnh tiếp theo là yêu cầu mới."
    }
    func state(_ value: Int) async {
        guard canCommand, let relay = selectedRelay, detail?.capabilities.manualSwitch == true else { return }
        await command { try await useCases.state(deviceID, relay: relay, value: value) }
    }
    func pulse(_ ms: Int) async {
        guard canCommand, let relay = selectedRelay, detail?.capabilities.pulse == true else { return }
        await command { try await useCases.pulse(deviceID, relay: relay, durationMS: ms) }
    }
    func refreshDevice() async {
        guard canCommand, detail?.capabilities.refresh == true else { return }
        await command { try await useCases.refresh(deviceID) }
    }
    private func command(_ operation: () async throws -> Void) async {
        generation += 1; let g = generation; isBusy = true; errorMessage = nil; notice = nil
        var commandError: String?
        do {
            try await operation()
            guard current(g) else { if active && generation == g { isBusy = false }; return }
            notice = "Đã gửi lệnh; chưa xác nhận trạng thái vật lý. Dữ liệu dưới đây là snapshot máy chủ."
        } catch {
            guard current(g) else { if active && generation == g { isBusy = false }; return }
            commandError = error.localizedDescription
        }
        isBusy = false
        await load()
        if active && generation == g + 1, let commandError {
            errorMessage = [commandError, errorMessage].compactMap { $0 }.joined(separator: "\n")
        }
    }
}
