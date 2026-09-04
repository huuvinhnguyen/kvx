//
//  Schedule.swift
//  kvx
//
//  Created by Vinh Nguyen on 4/9/26.
//

import Foundation

struct Schedule: Identifiable, Codable {
    let id: String
    let deviceId: String
    let time: Date
    let type: ScheduleType
    var isActive: Bool

    init(id: String = UUID().uuidString, deviceId: String, time: Date, type: ScheduleType, isActive: Bool = true) {
        self.id = id
        self.deviceId = deviceId
        self.time = time
        self.type = type
        self.isActive = isActive
    }

    enum ScheduleType: String, CaseIterable, Codable {
        case daily = "Hằng ngày"
        case weekly = "Hằng tuần"
        case once = "Một lần"
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    func copyWith(id: String? = nil, deviceId: String? = nil, time: Date? = nil, type: ScheduleType? = nil, isActive: Bool? = nil) -> Schedule {
        Schedule(
            id: id ?? self.id,
            deviceId: deviceId ?? self.deviceId,
            time: time ?? self.time,
            type: type ?? self.type,
            isActive: isActive ?? self.isActive
        )
    }
}

extension Schedule: Equatable {
    static func == (lhs: Schedule, rhs: Schedule) -> Bool {
        lhs.id == rhs.id
    }
}

extension Schedule: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
