//
//  Device.swift
//  kvx
//
//  Created by Vinh Nguyen on 22/4/26.
//

import Foundation
import SwiftUI

struct Device: Identifiable {
    let id = UUID()
    let name: String
    let type: DeviceType
    let status: DeviceStatus

    enum DeviceType: String, CaseIterable {
        case iPhone = "iPhone"
        case iPad = "iPad"
        case simulator = "Simulator"
    }

    enum DeviceStatus: String, CaseIterable {
        case online = "Online"
        case offline = "Offline"
        case busy = "Busy"

        var color: Color {
            switch self {
            case .online: return .green
            case .offline: return .gray
            case .busy: return .orange
            }
        }
    }
}

extension Device {
    static let sampleDevices: [Device] = [
        Device(name: "iPhone 16 Pro", type: .iPhone, status: .online),
        Device(name: "iPhone 15", type: .iPhone, status: .busy),
        Device(name: "iPhone 14 Pro", type: .iPhone, status: .offline),
        Device(name: "iPad Pro 13\"", type: .iPad, status: .online),
        Device(name: "iPad Air", type: .iPad, status: .offline),
        Device(name: "iPhone SE", type: .iPhone, status: .online),
        Device(name: "Vision Simulator", type: .simulator, status: .online),
    ]
}
