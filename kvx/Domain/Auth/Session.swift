import Foundation

nonisolated enum SessionPhase: Equatable, Sendable { case unknown, restoring, signedOut, authenticating, authenticated }
nonisolated enum SignOutReason: String, Sendable { case none, logout, expired, switching }

nonisolated struct SessionState: Equatable, Sendable {
    var phase: SessionPhase = .unknown
    var generation: UInt64 = 0
    var reason: SignOutReason = .none
    var message: String?
    var clearing = false
    var reconciliation: ReconciliationGate = .unavailable
}

nonisolated enum StoredSession: Equatable, Sendable {
    case active(String)
    case managed(ActiveSessionRecord)
    case quarantined(String)
    case signedOut
}

nonisolated enum ReconciliationOperation: String, Codable, Equatable, Sendable {
    case unlinkGoogle = "unlink_google"
    case rotateRecoveryCodes = "rotate_recovery_codes"
}

nonisolated struct ReconciliationMarker: Equatable, Sendable {
    let operationID: String
    let operation: ReconciliationOperation

    init(operation: ReconciliationOperation, operationID: String = UUID().uuidString.lowercased()) {
        self.operation = operation
        self.operationID = operationID
    }
}

nonisolated struct ActiveSessionRecord: Equatable, Sendable {
    let token: String
    let sessionID: String
    let marker: ReconciliationMarker?

    init(token: String, sessionID: String = UUID().uuidString.lowercased(), marker: ReconciliationMarker? = nil) {
        self.token = token
        self.sessionID = sessionID
        self.marker = marker
    }

    func replacing(marker: ReconciliationMarker?) -> ActiveSessionRecord {
        ActiveSessionRecord(token: token, sessionID: sessionID, marker: marker)
    }
}

nonisolated enum ReconciliationGate: Equatable, Sendable {
    case unavailable, clean, legacy, corrupt, pendingUnlink, pendingRotation, storageBlocked

    static func from(_ marker: ReconciliationMarker?) -> ReconciliationGate {
        switch marker?.operation {
        case nil: .clean
        case .unlinkGoogle: .pendingUnlink
        case .rotateRecoveryCodes: .pendingRotation
        }
    }
}

nonisolated struct MutationLease: Equatable, Sendable {
    let generation: UInt64
    let sessionID: String
    let marker: ReconciliationMarker
}

nonisolated enum MarkerResolution: Sendable {
    case provenNotDispatched, providerAbsent, lastMethodRejected, codesAcknowledged
}

nonisolated struct SessionSnapshot: Sendable {
    let token: String
    let generation: UInt64
}

nonisolated enum SessionFailure: Error, LocalizedError {
    case signedOut, stale, invalidToken, storage, login
    var errorDescription: String? {
        switch self {
        case .signedOut: return "Vui lòng đăng nhập Binblog."
        case .stale: return "Phiên đăng nhập đã thay đổi."
        case .invalidToken: return "Binblog không trả về phiên đăng nhập hợp lệ."
        case .storage: return "Không lưu được thay đổi phiên. Phiên cũ có thể khôi phục khi mở lại ứng dụng. Hãy thử lại."
        case .login: return "Đăng nhập thất bại. Kiểm tra tài khoản và kết nối rồi thử lại."
        }
    }
}

nonisolated enum AuthenticationAttemptFailure: Error, LocalizedError, Equatable, Sendable {
    case userCancelled
    case providerFailure
    case providerConfigurationFailure
    case missingCredential
    case networkFailure
    case invalidProviderCredential
    case linkRequired
    case emailVerificationRequired
    case providerUnavailable
    case usernameUnavailable
    case malformedResponse
    case serverFailure

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return nil
        case .providerFailure:
            return "Không thể đăng nhập bằng Google. Hãy thử lại."
        case .providerConfigurationFailure:
            return "Đăng nhập Google chưa được cấu hình cho bản dựng này."
        case .missingCredential:
            return "Google không trả về thông tin đăng nhập hợp lệ. Hãy thử lại."
        case .networkFailure:
            return "Không thể kết nối để đăng nhập. Kiểm tra mạng rồi thử lại."
        case .invalidProviderCredential:
            return "Phiên Google không còn hợp lệ. Hãy đăng nhập Google lại."
        case .linkRequired:
            return "Email này đã thuộc một tài khoản Binblog. Hãy đăng nhập bằng mật khẩu trước; ứng dụng sẽ không tự động liên kết tài khoản."
        case .emailVerificationRequired:
            return "Tài khoản Google cần có email đã xác minh để đăng nhập."
        case .providerUnavailable:
            return "Google tạm thời không khả dụng. Hãy thử lại sau."
        case .usernameUnavailable:
            return "Chưa thể tạo tài khoản Binblog. Hãy thử lại sau."
        case .malformedResponse, .serverFailure:
            return "Binblog chưa thể hoàn tất đăng nhập Google. Hãy thử lại sau."
        }
    }
}

nonisolated protocol SessionStore: Sendable {
    func read() async throws -> StoredSession?
    func write(_ value: StoredSession) async throws
    func delete() async throws
}

nonisolated protocol PasswordAuthenticating: Sendable {
    func login(username: String, password: String) async throws -> String
}

nonisolated protocol GoogleCredentialProviding: Sendable {
    @MainActor func credential() async throws -> String
    @MainActor func signOut() async throws
}

nonisolated protocol SocialSessionExchanging: Sendable {
    func exchange(provider: String, credential: String) async throws -> String
}

nonisolated protocol SessionAuthorizing: Sendable {
    func snapshot(expectedGeneration: UInt64?) async throws -> SessionSnapshot
    func isCurrent(_ generation: UInt64) async -> Bool
    // Starting the transport is synchronous within the owner's isolation.
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) async throws
    func unauthorized(_ generation: UInt64) async -> Bool
    func prepareMutation(_ operation: ReconciliationOperation, generation: UInt64) async throws -> MutationLease
    func pendingMutation(_ generation: UInt64) async throws -> MutationLease?
    func clearMutation(_ lease: MutationLease, resolution: MarkerResolution) async throws
    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws
    func reconciliationGate(_ generation: UInt64) async throws -> ReconciliationGate
    func refreshReconciliation(_ generation: UInt64) async throws -> ReconciliationGate
}

extension SessionAuthorizing {
    func prepareMutation(_ operation: ReconciliationOperation, generation: UInt64) async throws -> MutationLease { throw SessionFailure.storage }
    func pendingMutation(_ generation: UInt64) async throws -> MutationLease? { throw SessionFailure.storage }
    func clearMutation(_ lease: MutationLease, resolution: MarkerResolution) async throws { throw SessionFailure.storage }
    func reconciliationGate(_ generation: UInt64) async throws -> ReconciliationGate { .unavailable }
    func refreshReconciliation(_ generation: UInt64) async throws -> ReconciliationGate { throw SessionFailure.storage }
}

nonisolated struct NoSession: SessionAuthorizing {
    func snapshot(expectedGeneration: UInt64?) async throws -> SessionSnapshot { throw SessionFailure.signedOut }
    func isCurrent(_ generation: UInt64) async -> Bool { false }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) async throws { throw SessionFailure.signedOut }
    func unauthorized(_ generation: UInt64) async -> Bool { false }
    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws { throw SessionFailure.signedOut }
}
