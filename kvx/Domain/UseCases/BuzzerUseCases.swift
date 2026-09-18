import Foundation

struct BuzzerUseCases {
    let repository: any BuzzerRepository

    func load(deviceID: String) async throws -> BuzzerDetail {
        let detail = try await repository.detail(deviceID: deviceID)
        guard detail.id == deviceID else { throw BuzzerError.invalidResponse }
        return detail
    }

    func execute(_ command: BuzzerCommand, detail: BuzzerDetail) async throws -> BuzzerCommandReceipt {
        if command == .test && !detail.canTest { throw BuzzerError.invalidConfiguration }
        return try await repository.send(command, deviceID: detail.id)
    }
}
