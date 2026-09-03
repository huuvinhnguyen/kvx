import Foundation

struct FetchDevicesUseCase {
    private let repository: DeviceRepository

    init(repository: DeviceRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Device] {
        try await repository.fetchDevices()
    }
}