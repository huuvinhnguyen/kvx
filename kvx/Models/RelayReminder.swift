//
//  RelayReminder.swift
//  kvx
//
//  Created by Developer Agent on 06/09/2026.
//

import Foundation

struct RelayReminder: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let deviceId: String
    let relayIndex: Int
    let startTime: Date
    let duration: TimeInterval  // seconds
    let repeatType: ReminderRepeatType
    let isActive: Bool

    init(
        id: String = UUID().uuidString,
        deviceId: String,
        relayIndex: Int,
        startTime: Date,
        duration: TimeInterval,
        repeatType: ReminderRepeatType,
        isActive: Bool = true
    ) {
        precondition(relayIndex >= 0, "relayIndex must be >= 0")
        precondition(duration > 0, "duration must be positive")

        self.id = id
        self.deviceId = deviceId
        self.relayIndex = relayIndex
        self.startTime = startTime
        self.duration = duration
        self.repeatType = repeatType
        self.isActive = isActive
    }

    // Equatable based on id
    static func == (lhs: RelayReminder, rhs: RelayReminder) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
