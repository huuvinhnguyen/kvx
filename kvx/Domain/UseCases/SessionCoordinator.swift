import Foundation

actor SessionCoordinator: SessionAuthorizing {
    private let store: any SessionStore
    private let authentication: any PasswordAuthenticating
    private var token: String?
    private var revision: UInt64 = 0
    private var persistenceTail: Task<Void, Never> = Task {}
    private var observers: [UUID: AsyncStream<SessionState>.Continuation] = [:]
    private(set) var state = SessionState()

    init(store: any SessionStore, authentication: any PasswordAuthenticating) {
        self.store = store
        self.authentication = authentication
    }

    func changes() -> AsyncStream<SessionState> {
        let id = UUID()
        return AsyncStream { continuation in
            observers[id] = continuation
            continuation.yield(state)
            continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        }
    }

    private func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
    private func publish() { for observer in observers.values { observer.yield(state) } }

    private func serialized<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let previous = persistenceTail
        let task = Task { await previous.value; return try await operation() }
        persistenceTail = Task { _ = try? await task.value }
        return try await task.value
    }

    func restore() async {
        guard state.phase == .unknown || (state.phase == .restoring && state.message != nil) else { return }
        revision += 1
        let intent = revision
        state = SessionState(phase: .restoring, generation: state.generation)
        publish()
        do {
            let stored = try await serialized { [store] in try await store.read() }
            guard revision == intent else { return }
            if case .active(let candidate) = stored {
                guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.invalidToken }
                token = candidate
                state = SessionState(phase: .authenticated, generation: state.generation + 1)
            } else { state.phase = .signedOut }
            publish()
        } catch {
            guard revision == intent else { return }
            state.message = "Không đọc được phiên đã lưu. Hãy thử lại hoặc đăng xuất."
            publish()
        }
    }

    func login(username: String, password: String) async throws {
        try await authenticate { [authentication] in
            try await authentication.login(username: username, password: password)
        }
    }

    // Future identity-provider exchanges return a Binblog candidate here;
    // all installation, intent fencing and persistence remain provider-neutral.
    func authenticate(using exchange: @escaping @Sendable () async throws -> String) async throws {
        guard state.phase == .signedOut, state.message == nil, !state.clearing else { throw SessionFailure.signedOut }
        revision += 1
        let intent = revision
        state.phase = .authenticating
        publish()
        do {
            let candidate = try await exchange()
            guard revision == intent else { throw SessionFailure.stale }
            guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.invalidToken }
            do { try await serialized { [store] in try await store.write(.active(candidate)) } }
            catch { throw SessionFailure.storage }
            guard revision == intent else { throw SessionFailure.stale }
            token = candidate
            state = SessionState(phase: .authenticated, generation: state.generation + 1)
            publish()
        } catch {
            guard revision == intent else { throw SessionFailure.stale }
            state.phase = .signedOut
            // A failed/ambiguous write needs durable clearing before another login.
            if case SessionFailure.storage = error { state.message = SessionFailure.storage.localizedDescription }
            publish()
            if error is SessionFailure { throw error }
            throw SessionFailure.login
        }
    }

    @discardableResult
    func logout(reason: SignOutReason = .logout) async -> Bool {
        revision += 1
        let intent = revision
        token = nil
        state = SessionState(phase: .signedOut, generation: state.generation + 1, reason: reason, clearing: true)
        publish()
        do {
            try await serialized { [store] in
                do { try await store.write(.signedOut) }
                catch { try await store.delete() }
            }
            guard revision == intent else { return false }
            state.clearing = false
            publish()
            return true
        } catch {
            guard revision == intent else { return false }
            state.clearing = false
            state.message = SessionFailure.storage.localizedDescription
            publish()
            return false
        }
    }

    func switchAccount(username: String, password: String) async throws {
        guard await logout(reason: .switching) else { throw SessionFailure.storage }
        try await login(username: username, password: password)
    }

    func snapshot(expectedGeneration: UInt64? = nil) throws -> SessionSnapshot {
        guard state.phase == .authenticated, let token else { throw SessionFailure.signedOut }
        guard expectedGeneration == nil || expectedGeneration == state.generation else { throw SessionFailure.stale }
        return SessionSnapshot(token: token, generation: state.generation)
    }
    func isCurrent(_ generation: UInt64) -> Bool { state.phase == .authenticated && state.generation == generation }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) throws {
        guard isCurrent(generation) else { throw SessionFailure.stale }
        start()
    }
    func unauthorized(_ generation: UInt64) async -> Bool {
        guard isCurrent(generation) else { return false }
        _ = await logout(reason: .expired)
        return true
    }
}
