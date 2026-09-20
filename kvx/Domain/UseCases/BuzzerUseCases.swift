import Foundation

struct BuzzerUseCases {
    let repository: any BuzzerRepository

    func load(deviceID: String) async throws -> (BuzzerDetail, [BuzzerSource], [BuzzerMotionEvent]) {
        async let detail = repository.detail(deviceID: deviceID)
        async let sources = repository.linkedPIRs(deviceID: deviceID)
        async let events = repository.history(deviceID: deviceID)
        return try await (detail, sources, events)
    }

    func test(deviceID: String) async throws -> BuzzerTestReceipt {
        try await repository.test(deviceID: deviceID)
    }
}
