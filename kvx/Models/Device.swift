//
//  Device.swift
//  kvx
//
//  Created by Vinh Nguyen on 22/4/26.
//

import Foundation

struct Device: Identifiable {
    let id: String
    let chipID: String?
    let name: String
    let type: DeviceType
    let status: DeviceStatus
    let temperature: Double?
    let humidity: Double?

    // Relay-specific fields (nil for non-relay devices)
    let relayCount: Int?
    let relayChannels: [RelayChannel]?
    let firmwareVersion: String?
    let appVersion: String?
    let lastConnected: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        chipID: String? = nil,
        type: DeviceType,
        status: DeviceStatus,
        temperature: Double? = nil,
        humidity: Double? = nil,
        relayCount: Int? = nil,
        relayChannels: [RelayChannel]? = nil,
        firmwareVersion: String? = nil,
        appVersion: String? = nil,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.chipID = chipID
        self.type = type
        self.status = status
        self.temperature = temperature
        self.humidity = humidity
        self.relayCount = relayCount
        self.relayChannels = relayChannels
        self.firmwareVersion = firmwareVersion
        self.appVersion = appVersion
        self.lastConnected = lastConnected
    }

    enum DeviceType: String, CaseIterable {
        case pir = "PIR"
        case iPhone = "iPhone"
        case iPad = "iPad"
        case simulator = "Simulator"
        case temperature = "Temperature"
        case `switch` = "Switch"
    }

    enum DeviceStatus: String, CaseIterable {
        case online = "Online"
        case offline = "Offline"
        case busy = "Busy"

    }
}

extension Device {
    static let sampleDevices: [Device] = [
        Device(name: "Temp Sensor 01", type: .temperature, status: .online, temperature: 24.5, humidity: 58.0),
        Device(name: "iPhone 16 Pro", type: .iPhone, status: .online),
        Device(name: "iPhone 15", type: .iPhone, status: .busy),
        Device(name: "iPhone 14 Pro", type: .iPhone, status: .offline),
        Device(name: "iPad Pro 13\"", type: .iPad, status: .online),
        Device(name: "iPad Air", type: .iPad, status: .offline),
        Device(name: "iPhone SE", type: .iPhone, status: .online),
        Device(name: "Vision Simulator AAA", type: .simulator, status: .online),
    ]
}
