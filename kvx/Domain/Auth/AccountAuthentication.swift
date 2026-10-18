import Foundation

nonisolated enum ReauthenticationPurpose: String, Sendable {
    case rotateRecoveryCodes = "rotate_recovery_codes"
    case unlinkIdentity = "unlink_identity"
}

nonisolated struct ProviderMethod: Equatable, Sendable {
    let provider: String
    let usable: Bool
    let canUnlink: Bool
}

nonisolated struct AuthenticationMethods: Equatable, Sendable {
    let passwordUsable: Bool
    let providers: [ProviderMethod]
    let codesEnrolled: Bool
    var canUnlinkGoogle: Bool {
        passwordUsable && providers.contains { $0.provider == "google" && $0.usable && $0.canUnlink }
    }
}

nonisolated final class ReauthenticationGrant: @unchecked Sendable {
    let token: String
    let expiresAt: Date
    let purpose: ReauthenticationPurpose
    private let lock = NSLock()
    private var consumed = false
    init(token: String, expiresAt: Date, purpose: ReauthenticationPurpose) {
        self.token = token
        self.expiresAt = expiresAt
        self.purpose = purpose
    }
    func usable(for expected: ReauthenticationPurpose, now: Date = Date()) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !consumed && purpose == expected && now < expiresAt
    }
    func consume(for expected: ReauthenticationPurpose, now: Date = Date()) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard !consumed && purpose == expected && now < expiresAt else { return nil }
        consumed = true
        return token
    }
}

nonisolated enum AccountAuthFailure: Error, Equatable, Sendable, LocalizedError {
    case stale, cancelled, network, malformedResponse, authenticationRequired
    case invalidProviderCredential, malformedRequest, reauthenticationFailed
    case reauthenticationRequired, lastAuthenticationMethod, unsupportedMethod
    case unsupportedProvider, rateLimited, providerUnavailable, serverFailure
    case unknown, uncertain

    var uncertainWrite: Bool {
        switch self {
        case .network, .malformedResponse, .serverFailure, .uncertain: true
        default: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .authenticationRequired: "Phiên Binblog đã hết hạn."
        case .reauthenticationFailed: "Mật khẩu không đúng."
        case .reauthenticationRequired: "Xác minh lại trước khi tiếp tục."
        case .lastAuthenticationMethod: "Không thể gỡ phương thức đăng nhập cuối cùng."
        case .rateLimited: "Thao tác quá nhanh. Hãy thử lại sau."
        case .network: "Không thể kết nối. Kiểm tra mạng rồi thử lại."
        case .stale, .cancelled: nil
        default: "Binblog chưa thể hoàn tất thao tác. Hãy thử lại sau."
        }
    }
}

nonisolated protocol AccountAuthRepository: Sendable {
    func methods() async throws -> AuthenticationMethods
    func reauthenticate(password: String, purpose: ReauthenticationPurpose) async throws -> ReauthenticationGrant
    func rotateCodes(grant: ReauthenticationGrant, lease: MutationLease, beginDispatch: @escaping @Sendable () -> Bool) async throws -> [String]
    func unlinkGoogle(grant: ReauthenticationGrant, lease: MutationLease, beginDispatch: @escaping @Sendable () -> Bool) async throws
}
