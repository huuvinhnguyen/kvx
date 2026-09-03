//
//  Device.swift
//  kvx
//
//  Created by Vinh Nguyen on 22/4/26.
//

import Foundation

struct Device: Identifiable {
    let id: String
    let name: String
    let type: DeviceType
    let status: DeviceStatus
    let temperature: Double?
    let humidity: Double?

    init(id: String = UUID().uuidString, name: String, type: DeviceType, status: DeviceStatus, temperature: Double? = nil, humidity: Double? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.temperature = temperature
        self.humidity = humidity
    }

    enum DeviceType: String, CaseIterable {
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
