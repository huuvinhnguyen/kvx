import Foundation

actor SessionCoordinator: SessionAuthorizing {
    private let store: any SessionStore
    private let authentication: any PasswordAuthenticating
    private var token: String?
    private var record: ActiveSessionRecord?
    private var revision: UInt64 = 0
    private var preparingID: String?
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
            switch stored {
            case .active(let candidate):
                guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.invalidToken }
                token = candidate
                record = nil
                state = SessionState(phase: .authenticated, generation: state.generation + 1, reconciliation: .legacy)
            case .quarantined(let candidate):
                guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SessionFailure.invalidToken }
                token = candidate
                record = nil
                state = SessionState(phase: .authenticated, generation: state.generation + 1, reconciliation: .corrupt)
            case .managed(let restored):
                guard !restored.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw SessionFailure.invalidToken
                }
                token = restored.token
                record = restored
                state = SessionState(phase: .authenticated, generation: state.generation + 1,
                                     reconciliation: .from(restored.marker))
            case .signedOut, nil:
                state.phase = .signedOut
            }
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
            let installed = ActiveSessionRecord(token: candidate)
            do {
                try await serialized { [store] in
                    try await store.write(.managed(installed))
                    guard try await store.read() == .managed(installed) else { throw SessionFailure.storage }
                }
            }
            catch { throw SessionFailure.storage }
            guard revision == intent else { throw SessionFailure.stale }
            token = candidate
            record = installed
            state = SessionState(phase: .authenticated, generation: state.generation + 1, reconciliation: .clean)
            publish()
        } catch {
            guard revision == intent else { throw SessionFailure.stale }
            state.phase = .signedOut
            // A failed/ambiguous write needs durable clearing before another login.
            if case SessionFailure.storage = error { state.message = SessionFailure.storage.localizedDescription }
            publish()
            if error is SessionFailure || error is AuthenticationAttemptFailure { throw error }
            throw SessionFailure.login
        }
    }

    @discardableResult
    func logout(reason: SignOutReason = .logout) async -> Bool {
        revision += 1
        let intent = revision
        token = nil
        record = nil
        preparingID = nil
        state = SessionState(phase: .signedOut, generation: state.generation + 1, reason: reason, clearing: true)
        publish()
        do {
            try await serialized { [store] in
                do { try await store.write(.signedOut) }
                catch { try await store.delete() }
                let stored = try await store.read()
                guard stored == nil || stored == .signedOut else { throw SessionFailure.storage }
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

    func reconciliationGate(_ generation: UInt64) async throws -> ReconciliationGate {
        guard isCurrent(generation) else { throw SessionFailure.stale }
        return state.reconciliation
    }

    func pendingMutation(_ generation: UInt64) async throws -> MutationLease? {
        guard isCurrent(generation) else { throw SessionFailure.stale }
        guard let record else { return nil }
        guard let marker = record.marker else { return nil }
        return MutationLease(generation: generation, sessionID: record.sessionID, marker: marker)
    }

    func prepareMutation(_ operation: ReconciliationOperation, generation: UInt64) async throws -> MutationLease {
        guard isCurrent(generation), state.reconciliation == .clean, let current = record,
              current.marker == nil, preparingID == nil, !Task.isCancelled else { throw SessionFailure.storage }
        let intent = revision
        let marker = ReconciliationMarker(operation: operation)
        preparingID = marker.operationID
        defer { if preparingID == marker.operationID { preparingID = nil } }
        let updated = current.replacing(marker: marker)
        let lease = MutationLease(generation: generation, sessionID: current.sessionID, marker: marker)
        do {
            try await serialized { [store] in
                guard try await store.read() == .managed(current) else { throw SessionFailure.storage }
                try await store.write(.managed(updated))
                guard try await store.read() == .managed(updated) else { throw SessionFailure.storage }
            }
        } catch {
            if revision == intent && isCurrent(generation) {
                state.reconciliation = .storageBlocked
                publish()
            }
            throw SessionFailure.storage
        }
        guard revision == intent, isCurrent(generation) else { throw SessionFailure.stale }
        record = updated
        state.reconciliation = .from(marker)
        publish()
        guard !Task.isCancelled else { throw SessionFailure.stale }
        return lease
    }

    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws {
        guard isCurrent(lease.generation), record?.sessionID == lease.sessionID,
              record?.marker == lease.marker,
              state.reconciliation == .from(lease.marker) else { throw SessionFailure.stale }
        start()
    }

    func clearMutation(_ lease: MutationLease, resolution: MarkerResolution) async throws {
        guard isCurrent(lease.generation), record?.sessionID == lease.sessionID,
              record?.marker == lease.marker else { throw SessionFailure.stale }
        switch (lease.marker.operation, resolution) {
        case (_, .provenNotDispatched), (.unlinkGoogle, .providerAbsent),
             (.unlinkGoogle, .lastMethodRejected), (.rotateRecoveryCodes, .codesAcknowledged): break
        default: throw SessionFailure.storage
        }
        let intent = revision
        let expected = record!
        let clean = expected.replacing(marker: nil)
        do {
            try await serialized { [store] in
                guard try await store.read() == .managed(expected) else { throw SessionFailure.storage }
                try await store.write(.managed(clean))
                guard try await store.read() == .managed(clean) else { throw SessionFailure.storage }
            }
        } catch {
            if revision == intent && isCurrent(lease.generation), record?.marker == lease.marker {
                state.reconciliation = .storageBlocked
                publish()
            }
            throw SessionFailure.storage
        }
        guard revision == intent, isCurrent(lease.generation), record?.marker == lease.marker else { throw SessionFailure.stale }
        record = clean
        state.reconciliation = .clean
        publish()
    }

    func refreshReconciliation(_ generation: UInt64) async throws -> ReconciliationGate {
        guard isCurrent(generation), let current = record else { throw SessionFailure.storage }
        let intent = revision
        let stored = try await serialized { [store] in try await store.read() }
        guard revision == intent, isCurrent(generation), record == current else { throw SessionFailure.stale }
        guard case .managed(let refreshed) = stored, refreshed.sessionID == current.sessionID,
              refreshed.token == current.token else {
            state.reconciliation = .storageBlocked
            publish()
            throw SessionFailure.storage
        }
        record = refreshed
        state.reconciliation = .from(refreshed.marker)
        publish()
        return state.reconciliation
    }
}
