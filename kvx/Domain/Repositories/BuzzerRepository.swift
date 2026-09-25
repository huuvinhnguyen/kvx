import Foundation

protocol BuzzerRepository {
    func detail(deviceID: String) async throws -> BuzzerDetail
    func linkedPIRs(deviceID: String) async throws -> [BuzzerSource]
    func history(deviceID: String) async throws -> [BuzzerMotionEvent]
    func availablePIRs(deviceID: String) async throws -> [AvailableBuzzerPIR]
    func link(deviceID: String, configuration: BuzzerLinkConfiguration) async throws
    func unlink(deviceID: String, pirID: String) async throws
    func test(deviceID: String) async throws -> BuzzerTestReceipt
}
