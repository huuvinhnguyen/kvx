import Foundation

struct BuzzerUseCases {
    let repository: any BuzzerRepository

    func load(deviceID: String) async throws -> (BuzzerDetail, [BuzzerSource], [BuzzerMotionEvent]) {
        async let detail = repository.detail(deviceID: deviceID)
        async let sources = repository.linkedPIRs(deviceID: deviceID)
        async let events = repository.history(deviceID: deviceID)
        return try await (detail, sources, events)
    }

    func availablePIRs(deviceID: String) async throws -> [AvailableBuzzerPIR] { try await repository.availablePIRs(deviceID: deviceID) }
    func link(deviceID: String, configuration: BuzzerLinkConfiguration) async throws { try await repository.link(deviceID: deviceID, configuration: configuration) }
    func unlink(deviceID: String, pirID: String) async throws { try await repository.unlink(deviceID: deviceID, pirID: pirID) }

    func test(deviceID: String) async throws -> BuzzerTestReceipt {
        try await repository.test(deviceID: deviceID)
    }
}
