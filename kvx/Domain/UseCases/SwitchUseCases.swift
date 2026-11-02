import Foundation
import Observation

struct SwitchUseCases {
    let repository: any SwitchRepository
    var continuity = SwitchCommandContinuity()
    func detail(_ id: String) async throws -> SwitchDetail {
        let detail = try await repository.detail(deviceID: id)
        guard detail.id == id else { throw SwitchFailure.invalidData }
        return detail
    }
    func reminders(_ id: String, relay: Int, afterID: String? = nil) async throws -> SwitchReminderPage {
        try await repository.reminders(deviceID: id, relay: relay, afterID: afterID)
    }
    func statistics(_ id: String, relay: Int) async throws -> SwitchStatistics {
        try await repository.statistics(deviceID: id, relay: relay)
    }
    func state(_ id: String, relay: Int, value: Int) async throws {
        guard value == 0 || value == 1 else { throw SwitchFailure.validation }
        try await command(id) { try await repository.state(deviceID: id, relay: relay, value: value) }
    }
    func pulse(_ id: String, relay: Int, durationMS: Int) async throws {
        guard (1000...86400000).contains(durationMS), durationMS % 1000 == 0 else { throw SwitchFailure.validation }
        try await command(id) { try await repository.pulse(deviceID: id, relay: relay, durationMS: durationMS) }
    }
    func refresh(_ id: String) async throws { try await command(id) { try await repository.refresh(deviceID: id) } }
    private func command(_ id: String, operation: () async throws -> Void) async throws {
        guard continuity.begin(id) else { throw SwitchFailure.validation }
        var unknown = true
        defer { continuity.finish(id, unknown: unknown) }
        do { try await operation(); unknown = false }
        catch let error as SwitchFailure { unknown = error == .uncertain; throw error }
    }
}

@MainActor @Observable
final class SwitchCommandContinuity {
    private var inFlight: Set<String> = []
    private var unresolved: Set<String> = []
    func busy(_ id: String) -> Bool { inFlight.contains(id) }
    func uncertain(_ id: String) -> Bool { unresolved.contains(id) }
    func begin(_ id: String) -> Bool {
        guard !busy(id), !uncertain(id) else { return false }
        inFlight.insert(id); unresolved.insert(id); return true
    }
    func finish(_ id: String, unknown: Bool) {
        inFlight.remove(id)
        if !unknown { unresolved.remove(id) }
    }
    func reconcile(_ id: String) { if !busy(id) { unresolved.remove(id) } }
}
