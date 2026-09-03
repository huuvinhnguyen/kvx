//
//  DeviceViewModel.swift
//  kvx
//
//  Created by Vinh Nguyen on 22/4/26.
//

import Foundation
import SwiftUI

@Observable
final class DeviceViewModel {
    private let fetchDevicesUseCase: FetchDevicesUseCase
    var devices: [Device] = Device.sampleDevices
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedFilter: DeviceFilter = .all

    init(repository: DeviceRepository) {
        fetchDevicesUseCase = FetchDevicesUseCase(repository: repository)
    }

    enum DeviceFilter: String, CaseIterable {
        case all = "All"
        case online = "Online"
        case offline = "Offline"
        case busy = "Busy"
    }

    var filteredDevices: [Device] {
        var result = devices

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch selectedFilter {
        case .all:
            break
        case .online:
            result = result.filter { $0.status == .online }
        case .offline:
            result = result.filter { $0.status == .offline }
        case .busy:
            result = result.filter { $0.status == .busy }
        }

        return result
    }

    var onlineCount: Int {
        devices.filter { $0.status == .online }.count
    }

    var offlineCount: Int {
        devices.filter { $0.status == .offline }.count
    }

    var busyCount: Int {
        devices.filter { $0.status == .busy }.count
    }

    func loadDevices() async {
        isLoading = true
        errorMessage = nil
        do {
            devices = try await fetchDevicesUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadDevices()
    }

    func deleteDevices(at offsets: IndexSet) {
        let devicesToDelete = offsets.map { filteredDevices[$0] }
        for device in devicesToDelete {
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices.remove(at: index)
            }
        }
    }

    func moveDevices(from source: IndexSet, to destination: Int) {
        let devicesToMove = source.map { filteredDevices[$0] }
        var insertIndex = destination

        for device in devicesToMove {
            if let sourceIndex = devices.firstIndex(where: { $0.id == device.id }) {
                let adjustedDestination = sourceIndex < destination ? insertIndex - 1 : insertIndex
                devices.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: adjustedDestination)
                if sourceIndex < destination {
                    insertIndex -= 1
                }
            }
        }
    }

    func addDevice(name: String, type: Device.DeviceType, status: Device.DeviceStatus, temperature: Double? = nil, humidity: Double? = nil) {
        let newDevice = Device(name: name, type: type, status: status, temperature: temperature, humidity: humidity)
        devices.append(newDevice)
    }

    func toggleStatus(for device: Device) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            let currentStatus = devices[index].status
            let newStatus: Device.DeviceStatus
            switch currentStatus {
            case .online:
                newStatus = .offline
            case .offline:
                newStatus = .online
            case .busy:
                newStatus = .online
            }
            devices[index] = Device(
                id: device.id,
                name: device.name,
                type: device.type,
                status: newStatus,
                temperature: device.temperature,
                humidity: device.humidity
            )
        }
    }
}
