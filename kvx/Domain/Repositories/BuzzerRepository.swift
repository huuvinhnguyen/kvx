import Foundation

protocol BuzzerRepository {
    func detail(deviceID: String) async throws -> BuzzerDetail
    func linkedPIRs(deviceID: String) async throws -> [BuzzerSource]
    func history(deviceID: String) async throws -> [BuzzerMotionEvent]
    func test(deviceID: String) async throws -> BuzzerTestReceipt
}
