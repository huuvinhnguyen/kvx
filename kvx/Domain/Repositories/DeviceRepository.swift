import Foundation

protocol DeviceRepository {
    func fetchDevices() async throws -> [Device]
}