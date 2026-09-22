import Foundation

struct BuzzerDetail {
    let id: String
    let name: String
    let chipID: String
    let online: Bool
    let lastSeen: Date?
    let linkedPIRCount: Int
    let lastTriggeredAt: Date?
    let sources: [BuzzerSource]
    let events: [BuzzerMotionEvent]
}

struct BuzzerSource: Identifiable {
    let id: String
    let name: String
    let chipID: String
    let relayIndex: Int
    let longlast: Int?
}

struct BuzzerMotionEvent: Identifiable {
    let id: String
    let eventType: String
    let pirID: String
    let sourceName: String
    let sourceChipID: String
    let occurredAt: Date
    let relayIndex: Int
    let longlast: Int?
}

struct BuzzerTestReceipt {
    let message: String
    let relayIndex: Int?
    let longlast: Int?
}

enum BuzzerError: LocalizedError {
    case unavailable, invalidConfiguration, cooldown(Int), commandFailed, invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Chưa tải được dữ liệu mở rộng của Buzzer. Máy chủ có thể chưa hỗ trợ tính năng này hoặc tài khoản chưa có quyền truy cập."
        case .invalidConfiguration: return "Cấu hình Buzzer chưa hợp lệ."
        case .cooldown(let seconds): return "Vui lòng chờ \(seconds) giây trước khi test lại."
        case .commandFailed: return "Chưa xác định được kết quả gửi lệnh. Hãy tải lại dữ liệu trước khi quyết định gửi lại."
        case .invalidResponse: return "Dữ liệu Buzzer không hợp lệ. Hãy tải lại dữ liệu."
        }
    }
}
