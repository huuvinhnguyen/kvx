import Foundation

struct PIRStatistics: Decodable {
    let date: String
    let values: [Int]
    let total: Int
    var recent_events: [PIRMotionEvent]? = nil

    func validated() throws -> Self {
        guard values.count == 24, values.allSatisfy({ $0 >= 0 }), total == values.reduce(0, +) else {
            throw DeviceAPIError.invalidResponse
        }
        return self
    }
}

struct PIRHeatmap: Decodable {
    let data: [PIRDay]
}

struct PIRDay: Decodable, Identifiable {
    let date: String
    let count: Int
    var id: String { date }
    var shortLabel: String { String(date.suffix(2)) + "/" + String(date.dropFirst(5).prefix(2)) }
    var level: Int {
        switch count {
        case ...0: return 0
        case 1...3: return 1
        case 4...8: return 2
        case 9...15: return 3
        default: return 4
        }
    }
}

enum PIRCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func date(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

protocol PIRRepository {
    func statistics(chipID: String, date: String) async throws -> PIRStatistics
    func heatmap(chipID: String) async throws -> [PIRDay]
}

struct PIRMotionEvent: Decodable, Identifiable {
    let id: Int
    let event_type: String
    let occurred_at: String

    var timestamp: Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: occurred_at) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: occurred_at)
    }
}
