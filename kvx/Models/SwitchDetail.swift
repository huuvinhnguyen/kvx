import Foundation

nonisolated struct SwitchRelay: Decodable, Equatable {
    let index: Int
    let switchValue: Int?
    let durationMs: Int?
    let remindersActive: Bool?
}

nonisolated struct SwitchDetail: Decodable, Equatable {
    let id: String
    let name: String
    let chipId: String
    let deviceType: String
    let timezone: String
    let lastSeen: String?
    let online: Bool?
    let stateSource: String
    let physicalStateVerified: Bool
    let capabilities: Capabilities
    let limits: Limits
    let relays: [SwitchRelay]
    struct Capabilities: Decodable, Equatable {
        let manualSwitch: Bool
        let pulse: Bool
        let refresh: Bool
        let statistics: Bool
        let reminders: Bool
    }
    struct Limits: Decodable, Equatable {
        let durationMinMs: Int
        let durationMaxMs: Int
        let reminderLimitPerRelay: Int
    }
}

nonisolated struct SwitchReminder: Decodable, Identifiable, Equatable {
    let id: String
    let deviceId: String
    let relayIndex: Int
    let startTime: String?
    let durationMs: Int?
    let repeatType: String
    let enabled: Bool
    let configurationValid: Bool
}

nonisolated struct SwitchReminderPage: Decodable {
    let status: String
    let reminders: [SwitchReminder]
    let nextAfterId: String?
}

nonisolated struct SwitchStatistics: Decodable, Equatable {
    let status: String
    let timezone: String
    let from: String
    let to: String
    let metric: String
    let totalRecords: Int
    let days: [Day]
    let physicalRuntimeSeconds: Int?
    let physicalRuntimeVerified: Bool
    struct Day: Decodable, Equatable { let date: String; let count: Int }
}

nonisolated enum SwitchFailure: Error, LocalizedError, Equatable {
    case authentication, unavailable, validation, connection, invalidData, uncertain
    var errorDescription: String? {
        switch self {
        case .authentication: "Phiên đăng nhập đã hết hạn."
        case .unavailable: "Switch hoặc tính năng chưa khả dụng."
        case .validation: "Cấu hình hoặc dữ liệu không hợp lệ."
        case .connection: "Không tải được dữ liệu. Hãy tải lại."
        case .invalidData: "Máy chủ trả về dữ liệu không hợp lệ."
        case .uncertain: "Chưa xác định lệnh đã được gửi hay chưa. Không tự gửi lại. Hãy kiểm tra thiết bị."
        }
    }
}

nonisolated enum SwitchDuration {
    static func milliseconds(_ text: String, minutes: Bool) -> Int? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(raw), (1...(minutes ? 1440 : 86400)).contains(value) else { return nil }
        return value * (minutes ? 60000 : 1000)
    }
}

nonisolated enum SwitchTimestamp {
    static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: raw)
    }
}
