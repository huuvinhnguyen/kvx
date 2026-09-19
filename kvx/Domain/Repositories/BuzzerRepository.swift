import Foundation

protocol BuzzerRepository {
    func detail(deviceID: String) async throws -> BuzzerDetail
    func send(_ command: BuzzerCommand, deviceID: String) async throws -> BuzzerCommandReceipt
}
