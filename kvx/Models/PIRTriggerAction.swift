import Foundation

enum PIRTriggerConfigurationMode: Equatable {
    case empty, actions, legacy, invalidLegacy
}

struct PIRTriggerSource: Equatable {
    let id: Int
    let name: String?
    let chipID: String
}

struct PIRTriggerDurationBounds: Equatable {
    let minimum: Int
    let maximum: Int

    func contains(_ value: Int) -> Bool { minimum...maximum ~= value }
}

struct PIRTriggerTarget: Identifiable, Equatable {
    enum DeviceType: String, Equatable { case `switch`, buzzer }
    let id: Int
    let chipID: String
    let name: String?
    let deviceType: DeviceType
    let relayIndexes: [Int]
    let durationBounds: PIRTriggerDurationBounds

    var displayName: String { name?.isEmpty == false ? name! : chipID }
}

struct PIRTriggerAction: Identifiable, Equatable {
    enum Origin: String, Equatable { case persisted, legacy }
    let id: Int?
    let origin: Origin
    let target: TargetSummary?
    let relayIndex: Int
    let durationMilliseconds: Int
    let delayMilliseconds: Int
    let enabled: Bool
    let position: Int

    struct TargetSummary: Equatable {
        let id: Int
        let name: String?
        let chipID: String
        let deviceType: PIRTriggerTarget.DeviceType
        var displayName: String { name?.isEmpty == false ? name! : chipID }
    }

    var stableID: String { id.map(String.init) ?? "legacy" }
}

struct PIRTriggerConfiguration: Equatable {
    let mode: PIRTriggerConfigurationMode
    let source: PIRTriggerSource
    let actions: [PIRTriggerAction]
}

struct PIRTriggerSnapshot: Equatable {
    let configuration: PIRTriggerConfiguration
    let targets: [PIRTriggerTarget]
}

struct PIRTriggerActionDraft: Equatable {
    let targetID: Int
    let relayIndex: Int
    let durationMilliseconds: Int
    let enabled: Bool

    func isValid(using targets: [PIRTriggerTarget]) -> Bool {
        guard let target = targets.first(where: { $0.id == targetID }) else { return false }
        return target.relayIndexes.contains(relayIndex) && target.durationBounds.contains(durationMilliseconds)
    }
}

enum PIRTriggerActionFailure: LocalizedError, Equatable {
    case authentication
    case unavailable(code: String, message: String)
    case rejected(code: String, message: String)
    case featureDisabled(message: String)
    case connection
    case invalidResponse
    case uncertainMutation

    var errorDescription: String? {
        switch self {
        case .authentication: return "Phiên đăng nhập không còn hợp lệ."
        case .unavailable(_, let message), .rejected(_, let message), .featureDisabled(let message): return message
        case .connection: return "Không tải được cấu hình hành động. Hãy kiểm tra kết nối và thử lại."
        case .invalidResponse: return "Máy chủ trả về cấu hình hành động không hợp lệ."
        case .uncertainMutation: return "Chưa xác nhận được kết quả cập nhật. Hãy tải lại trước khi chỉnh sửa tiếp."
        }
    }
}
