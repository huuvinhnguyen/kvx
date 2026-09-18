import Foundation

struct BuzzerDetail {
    let id: String
    let name: String
    let chipID: String
    let online: Bool
    let lastSeen: Date?
    let buildVersion: String?
    let appVersion: String?
    let testDurationMS: Int?
    let sources: [BuzzerSource]
    let events: [BuzzerMotionEvent]

    var canTest: Bool {
        testDurationMS.map { (100...10_000).contains($0) } ?? false
    }
}

struct BuzzerSource: Identifiable {
    let id: String
    let name: String
    let chipID: String
    let relayIndex: Int
    let durationMS: Int?
}

struct BuzzerMotionEvent: Identifiable {
    let id: String
    let sourceID: String
    let sourceName: String
    let sourceChipID: String
    let occurredAt: Date
    let durationMS: Int?
}

enum BuzzerCommand: String, CaseIterable, Identifiable {
    case test, refresh, restart
    case resetWifi = "reset_wifi"
    var id: String { rawValue }
}

struct BuzzerCommandReceipt {
    let cooldownSeconds: Int
}

enum BuzzerError: LocalizedError {
    case unavailable, invalidConfiguration, cooldown(Int), commandFailed, invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Chưa tải được dữ liệu mở rộng của Buzzer. Máy chủ có thể chưa hỗ trợ tính năng này hoặc tài khoản chưa có quyền truy cập."
        case .invalidConfiguration: return "Cấu hình Buzzer chưa hợp lệ. Thời lượng test phải từ 100 đến 10.000 ms."
        case .cooldown(let seconds): return "Vui lòng chờ \(seconds) giây trước khi test lại."
        case .commandFailed: return "Chưa xác định được kết quả gửi lệnh. Hãy tải lại dữ liệu trước khi quyết định gửi lại."
        case .invalidResponse: return "Dữ liệu Buzzer không hợp lệ. Hãy tải lại dữ liệu."
        }
    }
}
