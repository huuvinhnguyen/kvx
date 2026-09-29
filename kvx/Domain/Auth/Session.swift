import Foundation

nonisolated enum SessionPhase: Equatable, Sendable { case unknown, restoring, signedOut, authenticating, authenticated }
nonisolated enum SignOutReason: String, Sendable { case none, logout, expired, switching }

nonisolated struct SessionState: Equatable, Sendable {
    var phase: SessionPhase = .unknown
    var generation: UInt64 = 0
    var reason: SignOutReason = .none
    var message: String?
    var clearing = false
}

nonisolated enum StoredSession: Codable, Equatable, Sendable {
    case active(String)
    case signedOut
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

nonisolated protocol SessionStore: Sendable {
    func read() async throws -> StoredSession?
    func write(_ value: StoredSession) async throws
    func delete() async throws
}

nonisolated protocol PasswordAuthenticating: Sendable {
    func login(username: String, password: String) async throws -> String
}

nonisolated protocol SessionAuthorizing: Sendable {
    func snapshot(expectedGeneration: UInt64?) async throws -> SessionSnapshot
    func isCurrent(_ generation: UInt64) async -> Bool
    // Starting the transport is synchronous within the owner's isolation.
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) async throws
    func unauthorized(_ generation: UInt64) async -> Bool
}

nonisolated struct NoSession: SessionAuthorizing {
    func snapshot(expectedGeneration: UInt64?) async throws -> SessionSnapshot { throw SessionFailure.signedOut }
    func isCurrent(_ generation: UInt64) async -> Bool { false }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) async throws { throw SessionFailure.signedOut }
    func unauthorized(_ generation: UInt64) async -> Bool { false }
}
