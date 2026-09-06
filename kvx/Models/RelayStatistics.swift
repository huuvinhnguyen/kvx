//
//  RelayStatistics.swift
//  kvx
//
//  Created by Developer Agent on 06/09/2026.
//

import Foundation

struct RelayStatistics: Equatable, Hashable, Codable {
    let deviceId: String
    let relayIndex: Int
    let totalOnTime: TimeInterval  // seconds
    let activationCount: Int
    let lastActivated: Date?

    init(
        deviceId: String,
        relayIndex: Int,
        totalOnTime: TimeInterval,
        activationCount: Int,
        lastActivated: Date? = nil
    ) {
        self.deviceId = deviceId
        self.relayIndex = relayIndex
        self.totalOnTime = totalOnTime
        self.activationCount = activationCount
        self.lastActivated = lastActivated
    }

    // Equatable based on deviceId and relayIndex
    static func == (lhs: RelayStatistics, rhs: RelayStatistics) -> Bool {
        lhs.deviceId == rhs.deviceId && lhs.relayIndex == rhs.relayIndex
    }

    // Hashable based on deviceId and relayIndex
    func hash(into hasher: inout Hasher) {
        hasher.combine(deviceId)
        hasher.combine(relayIndex)
    }
}
