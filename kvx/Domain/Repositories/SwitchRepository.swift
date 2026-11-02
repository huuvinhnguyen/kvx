import Foundation

protocol SwitchRepository {
    func detail(deviceID: String) async throws -> SwitchDetail
    func reminders(deviceID: String, relay: Int, afterID: String?) async throws -> SwitchReminderPage
    func statistics(deviceID: String, relay: Int) async throws -> SwitchStatistics
    func state(deviceID: String, relay: Int, value: Int) async throws
    func pulse(deviceID: String, relay: Int, durationMS: Int) async throws
    func refresh(deviceID: String) async throws
}
