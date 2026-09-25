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
    let relayIndex: Int?
    let longlast: Int?
    var relayDisplay: String? = nil
    var longlastDisplay: String? = nil
}

struct BuzzerMotionEvent: Identifiable {
    let id: String
    let eventType: String
    let pirID: String
    let sourceName: String
    let sourceChipID: String
    let occurredAt: Date
    let relayIndex: Int?
    let longlast: Int?
    var relayDisplay: String? = nil
    var longlastDisplay: String? = nil
}

struct BuzzerTestReceipt {
    let message: String
    let relayIndex: Int?
    let longlast: Int?
}

enum BuzzerError: LocalizedError {
    case unavailable, invalidConfiguration, cooldown(Int), commandFailed, invalidResponse, uncertainMutation

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Chưa tải được dữ liệu mở rộng của Buzzer. Máy chủ có thể chưa hỗ trợ tính năng này hoặc tài khoản chưa có quyền truy cập."
        case .invalidConfiguration: return "Cấu hình Buzzer chưa hợp lệ."
        case .cooldown(let seconds): return "Vui lòng chờ \(seconds) giây trước khi test lại."
        case .commandFailed: return "Chưa xác định được kết quả gửi lệnh. Hãy tải lại dữ liệu trước khi quyết định gửi lại."
        case .invalidResponse: return "Dữ liệu Buzzer không hợp lệ. Hãy tải lại dữ liệu."
        case .uncertainMutation: return "Chưa xác nhận được kết quả cập nhật cấu hình. Hãy tải lại dữ liệu trước khi chỉnh sửa tiếp."
        }
    }
}

struct AvailableBuzzerPIR: Identifiable {
    let id: String
    let name: String?
    let chipID: String
    let linkedBuzzer: LinkedBuzzer?
    let requiresConfirmation: Bool

    var displayName: String { name?.isEmpty == false ? name! : chipID }
    func confirmation(currentBuzzerID: String) -> String? {
        if let linkedBuzzer, linkedBuzzer.id != currentBuzzerID {
            return "PIR sẽ ngừng kích hoạt \(linkedBuzzer.name ?? "Buzzer hiện tại") và chuyển sang Buzzer này. Bạn muốn chuyển & liên kết?"
        }
        return requiresConfirmation ? "Cấu hình hiện có của PIR sẽ bị thay thế bằng liên kết với Buzzer này. Bạn muốn thay thế & liên kết?" : nil
    }
}

struct LinkedBuzzer { let id: String; let name: String? }

struct BuzzerLinkConfiguration {
    let pirID: String
    let relayIndex: Int
    let longlast: Int
    var isValid: Bool { (Int(pirID) ?? 0) > 0 && relayIndex >= 0 && (100...10000).contains(longlast) }
}
