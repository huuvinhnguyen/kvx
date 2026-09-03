import Foundation

struct RemoteDeviceRepository: DeviceRepository {
    private let dataSource: BinblogDeviceDataSource

    init(dataSource: BinblogDeviceDataSource = BinblogDeviceDataSource()) {
        self.dataSource = dataSource
    }

    func fetchDevices() async throws -> [Device] {
        try await dataSource.fetchDevices()
    }
}