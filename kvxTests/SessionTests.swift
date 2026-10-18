import Foundation
import Security
import Testing
@testable import kvx

// Mapping fixtures do not mutate session state; coordinator tests below exercise invalidation.
struct FixedTestSession: SessionAuthorizing {
    let token: String
    func snapshot(expectedGeneration: UInt64?) async throws -> SessionSnapshot {
        SessionSnapshot(token: token, generation: 1)
    }
    func isCurrent(_ generation: UInt64) async -> Bool { generation == 1 }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) async throws { start() }
    func unauthorized(_ generation: UInt64) async -> Bool { true }
    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws { throw SessionFailure.storage }
}

private actor MemorySessionStore: SessionStore {
    var value: StoredSession?
    var reads = 0
    var writes: [StoredSession] = []
    var deletes = 0
    var failRead = false
    var failWrite = false
    var failAfterWrite = false
    var failReadBack = false
    var readBackArmed = false
    var failDelete = false
    var pauseWrite = false
    var pauseRead = false
    var pendingRead: CheckedContinuation<Void, Never>?
    var pendingWrite: CheckedContinuation<Void, Never>?
    init(_ value: StoredSession? = nil) { self.value = value }
    func configure(read: Bool = false, write: Bool = false, delete: Bool = false, pause: Bool = false) {
        failRead = read; failWrite = write; failDelete = delete; pauseWrite = pause
    }
    func configureMarkerFault(afterWrite: Bool = false, readBack: Bool = false) {
        failAfterWrite = afterWrite; failReadBack = readBack
    }
    func pauseRestoration() { pauseRead = true }
    func resumeRead() { pendingRead?.resume(); pendingRead = nil }
    func read() async throws -> StoredSession? {
        reads += 1
        let captured = value
        if pauseRead { await withCheckedContinuation { pendingRead = $0 }; pauseRead = false }
        if failRead { throw SessionFailure.storage }
        if readBackArmed { readBackArmed = false; throw SessionFailure.storage }
        return captured
    }
    func write(_ value: StoredSession) async throws {
        writes.append(value)
        if pauseWrite { await withCheckedContinuation { pendingWrite = $0 }; pauseWrite = false }
        if failWrite { throw SessionFailure.storage }
        self.value = value
        if failReadBack { readBackArmed = true }
        if failAfterWrite { throw SessionFailure.storage }
    }
    func resumeWrite() { pendingWrite?.resume(); pendingWrite = nil }
    func delete() throws {
        deletes += 1
        if failDelete { throw SessionFailure.storage }
        value = nil
    }
}

private actor SessionLoginFake: PasswordAuthenticating {
    var calls = 0
    var result = "session-B"
    var fails = false
    var paused = false
    var pending: CheckedContinuation<String, Error>?
    func configure(result: String = "session-B", fails: Bool = false, paused: Bool = false) {
        self.result = result; self.fails = fails; self.paused = paused
    }
    func login(username: String, password: String) async throws -> String {
        calls += 1
        if paused { return try await withCheckedThrowingContinuation { pending = $0 } }
        if fails { throw SessionFailure.login }
        return result
    }
    func finish() { pending?.resume(returning: result); pending = nil }
}

private final class MarkerDispatchProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func start() { lock.lock(); count += 1; lock.unlock() }
    var starts: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@MainActor
struct SessionCoordinatorTests {
    @Test func storedSessionRestoresLocallyOnceWithoutAuthentication() async throws {
        let store = MemorySessionStore(.active("opaque-session"))
        let login = SessionLoginFake()
        let coordinator = SessionCoordinator(store: store, authentication: login)
        await coordinator.restore(); await coordinator.restore()
        #expect(await coordinator.state.phase == .authenticated)
        #expect(try await coordinator.snapshot().token == "opaque-session")
        #expect(await store.reads == 1)
        #expect(await login.calls == 0)
    }

    @Test func absentOrSignedOutStorageDoesNotAuthenticate() async {
        let values: [StoredSession?] = [nil, .signedOut]
        for value in values {
            let login = SessionLoginFake()
            let coordinator = SessionCoordinator(store: MemorySessionStore(value), authentication: login)
            await coordinator.restore()
            #expect(await coordinator.state.phase == .signedOut)
            #expect(await login.calls == 0)
        }
    }

    @Test func readFailureIsRecoverableAndDoesNotLogin() async {
        let store = MemorySessionStore(.active("session-A"))
        await store.configure(read: true)
        let login = SessionLoginFake()
        let coordinator = SessionCoordinator(store: store, authentication: login)
        await coordinator.restore()
        #expect(await coordinator.state.phase == .restoring)
        #expect(await coordinator.state.message != nil)
        #expect(await login.calls == 0)
        await store.configure()
        await coordinator.restore()
        #expect(await coordinator.state.phase == .authenticated)
    }

    @Test func passwordCandidateIsPersistedBeforePublication() async throws {
        let store = MemorySessionStore()
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        await store.configure(pause: true)
        let request = Task { try await coordinator.login(username: "fixture", password: "fixture") }
        while await store.pendingWrite == nil { await Task.yield() }
        #expect(await coordinator.state.phase == .authenticating)
        await store.resumeWrite()
        try await request.value
        #expect(await coordinator.state.phase == .authenticated)
        guard case .managed(let installed) = await store.value else { Issue.record("Expected v2 session record"); return }
        #expect(installed.token == "session-B")
        #expect(installed.marker == nil)
    }

    @Test func rejectedLoginAndInvalidTokenInstallNothing() async {
        for invalid in [false, true] {
            let store = MemorySessionStore()
            let login = SessionLoginFake()
            await login.configure(result: invalid ? " \n" : "session-B", fails: !invalid)
            let coordinator = SessionCoordinator(store: store, authentication: login)
            await coordinator.restore()
            do { try await coordinator.login(username: "fixture", password: "fixture"); Issue.record("Expected rejected login") }
            catch {}
            #expect(await coordinator.state.phase == .signedOut)
            #expect(await store.writes.isEmpty)
        }
    }

    @Test func concurrentUnauthorizedInvalidatesOnlyOnce() async throws {
        let store = MemorySessionStore(.active("session-A"))
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        let generation = try await coordinator.snapshot().generation
        async let first = coordinator.unauthorized(generation)
        async let second = coordinator.unauthorized(generation)
        let results = await [first, second]
        #expect(results.filter { $0 }.count == 1)
        #expect(await coordinator.state.reason == .expired)
        #expect(await store.writes == [.signedOut])
    }

    @Test func logoutIsDurableAcrossRestart() async {
        let store = MemorySessionStore(.active("session-A"))
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        #expect(await coordinator.logout())
        let restarted = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await restarted.restore()
        #expect(await restarted.state.phase == .signedOut)
    }

    @Test func logoutRejectsPendingLoginBeforeAnyWrite() async {
        let store = MemorySessionStore()
        let login = SessionLoginFake()
        await login.configure(paused: true)
        let coordinator = SessionCoordinator(store: store, authentication: login)
        await coordinator.restore()
        let request = Task { try await coordinator.login(username: "fixture", password: "fixture") }
        while await login.pending == nil { await Task.yield() }
        #expect(await coordinator.logout())
        await login.finish()
        do { try await request.value; Issue.record("Expected stale login") } catch SessionFailure.stale {} catch { Issue.record("Wrong stale-login error") }
        #expect(await store.writes == [.signedOut])
        #expect(await coordinator.state.phase == .signedOut)
    }

    @Test func logoutSerializesBehindAlreadyStartedLoginWrite() async {
        let store = MemorySessionStore()
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        await store.configure(pause: true)
        let login = Task { try await coordinator.login(username: "fixture", password: "fixture") }
        while await store.pendingWrite == nil { await Task.yield() }
        let logout = Task { await coordinator.logout() }
        while await coordinator.state.phase != .signedOut { await Task.yield() }
        await store.resumeWrite()
        _ = try? await login.value
        #expect(await logout.value)
        #expect(await store.value == .signedOut)
        #expect(await coordinator.state.phase == .signedOut)
    }

    @Test func switchingFencesOldGenerationAndReinstallingSameTokenChangesGeneration() async throws {
        let login = SessionLoginFake()
        await login.configure(result: "same-token")
        let coordinator = SessionCoordinator(store: MemorySessionStore(.active("same-token")), authentication: login)
        await coordinator.restore()
        let old = try await coordinator.snapshot()
        try await coordinator.switchAccount(username: "fixture", password: "fixture")
        let new = try await coordinator.snapshot()
        #expect(old.generation != new.generation)
        #expect(old.token == new.token)
        #expect(!(await coordinator.isCurrent(old.generation)))
        #expect(!(await coordinator.unauthorized(old.generation)))
        #expect(await coordinator.state.phase == .authenticated)
    }

    @Test func failedSwitchStaysSignedOut() async {
        let login = SessionLoginFake()
        await login.configure(fails: true)
        let coordinator = SessionCoordinator(store: MemorySessionStore(.active("session-A")), authentication: login)
        await coordinator.restore()
        do { try await coordinator.switchAccount(username: "fixture", password: "fixture"); Issue.record("Expected failure") } catch {}
        #expect(await coordinator.state.phase == .signedOut)
    }

    @Test func pendingRestoreCannotInstallAfterLogout() async {
        let store = MemorySessionStore(.active("session-A"))
        await store.pauseRestoration()
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        let restore = Task { await coordinator.restore() }
        while await store.pendingRead == nil { await Task.yield() }
        let logout = Task { await coordinator.logout() }
        while await coordinator.state.phase != .signedOut { await Task.yield() }
        await store.resumeRead()
        await restore.value
        #expect(await logout.value)
        #expect(await coordinator.state.phase == .signedOut)
        #expect(await store.value == .signedOut)
    }

    @Test func loginCannotStartWhileDurableLogoutIsPending() async {
        let store = MemorySessionStore(.active("session-A"))
        let authentication = SessionLoginFake()
        let coordinator = SessionCoordinator(store: store, authentication: authentication)
        await coordinator.restore()
        await store.configure(pause: true)
        let logout = Task { await coordinator.logout() }
        while await store.pendingWrite == nil { await Task.yield() }
        do { try await coordinator.login(username: "fixture", password: "fixture"); Issue.record("Login must wait for durable clearing") } catch {}
        #expect(await authentication.calls == 0)
        await store.resumeWrite()
        #expect(await logout.value)
    }

    @Test func signedOutReplacementProvidesDurableLogoutWhenDeleteIsUnavailable() async {
        let store = MemorySessionStore(.active("session-A"))
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        await store.configure(delete: true)
        #expect(await coordinator.logout())
        #expect(await store.value == .signedOut)
        let restarted = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await restarted.restore()
        #expect(await restarted.state.phase == .signedOut)
    }

    @Test func signedOutWriteFailureFallsBackToDeletion() async {
        let store = MemorySessionStore(.active("session-A"))
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        await store.configure(write: true)
        #expect(await coordinator.logout())
        #expect(await store.deletes == 1)
        #expect(await store.value == nil)
    }

    @Test func totalClearFailureBlocksRequestsAndSwitchButRestartMayRestore() async {
        let store = MemorySessionStore(.active("session-A"))
        let login = SessionLoginFake()
        let coordinator = SessionCoordinator(store: store, authentication: login)
        await coordinator.restore()
        await store.configure(write: true, delete: true)
        #expect(!(await coordinator.logout()))
        #expect(await coordinator.state.message != nil)
        do { _ = try await coordinator.snapshot(); Issue.record("Expected signed out") } catch {}
        do { try await coordinator.switchAccount(username: "fixture", password: "fixture"); Issue.record("Expected blocked switch") } catch {}
        #expect(await login.calls == 0)
        let restarted = SessionCoordinator(store: store, authentication: login)
        await restarted.restore()
        #expect(await restarted.state.phase == .authenticated)
    }

    @Test func failedLoginPersistenceCannotPublishAuthentication() async {
        let store = MemorySessionStore()
        await store.configure(write: true)
        let coordinator = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await coordinator.restore()
        do { try await coordinator.login(username: "fixture", password: "fixture"); Issue.record("Expected storage failure") } catch {}
        #expect(await coordinator.state.phase == .signedOut)
        #expect(await coordinator.state.message != nil)
    }

    @Test func legacyAndCorruptSessionsRemainReadableButQuarantineWrites() async throws {
        for stored in [StoredSession.active("dummy-jwt"), .quarantined("dummy-jwt")] {
            let session = SessionCoordinator(store: MemorySessionStore(stored), authentication: SessionLoginFake())
            await session.restore()
            let generation = try await session.snapshot().generation
            #expect(try await session.snapshot().token == "dummy-jwt")
            #expect(await session.state.reconciliation == (stored == .active("dummy-jwt") ? .legacy : .corrupt))
            do {
                _ = try await session.prepareMutation(.unlinkGoogle, generation: generation)
                Issue.record("Quarantined session prepared a mutation")
            } catch SessionFailure.storage {} catch { Issue.record("Wrong quarantine failure") }
        }
    }

    @Test func malformedManagedTokenNeverInstallsAuthentication() async {
        let session = SessionCoordinator(store: MemorySessionStore(.managed(ActiveSessionRecord(token: " \n"))),
                                         authentication: SessionLoginFake())
        await session.restore()
        #expect(await session.state.phase == .restoring)
        #expect(await session.state.message != nil)
    }

    @Test func prepareReadbackPrecedesDispatchAndRestoresUnlinkLock() async throws {
        let store = MemorySessionStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
        let session = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await session.restore()
        let generation = try await session.snapshot().generation
        let lease: MutationLease
        do { lease = try await session.prepareMutation(.unlinkGoogle, generation: generation) }
        catch { Issue.record("Coordinator marker preparation failed: \(type(of: error))"); return }
        guard case .managed(let persisted) = await store.value else { Issue.record("Missing v2 record"); return }
        #expect(persisted.marker == lease.marker)
        let probe = MarkerDispatchProbe()
        do { try await session.dispatchPrepared(lease) { probe.start() } }
        catch { Issue.record("Coordinator dispatch fence failed: \(type(of: error))"); return }
        #expect(probe.starts == 1)

        let restarted = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await restarted.restore()
        #expect(await restarted.state.reconciliation == .pendingUnlink)
        let restartedGeneration = try await restarted.snapshot().generation
        do {
            _ = try await restarted.prepareMutation(.rotateRecoveryCodes, generation: restartedGeneration)
            Issue.record("Pending Unlink permitted another write")
        } catch SessionFailure.storage {} catch { Issue.record("Wrong pending-marker failure") }
        let currentLease = try #require(await restarted.pendingMutation(restartedGeneration))
        #expect(currentLease.sessionID == lease.sessionID && currentLease.marker == lease.marker)
        do { try await restarted.clearMutation(currentLease, resolution: .providerAbsent) }
        catch { Issue.record("Coordinator conditional clear failed: \(type(of: error))"); return }
        #expect(await restarted.state.reconciliation == .clean)
        #expect(await store.value == .managed(persisted.replacing(marker: nil)))
    }

    @Test func preparedMarkerWithoutDispatchLocksRestoredGraph() async throws {
        let store = MemorySessionStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
        let first = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await first.restore()
        let generation = try await first.snapshot().generation
        let lease = try await first.prepareMutation(.unlinkGoogle, generation: generation)
        guard case .managed(let persisted) = await store.value else { Issue.record("Missing prepared record"); return }
        #expect(persisted.marker == lease.marker)
        let dispatch = MarkerDispatchProbe()
        #expect(dispatch.starts == 0)

        let restarted = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await restarted.restore()
        #expect(await restarted.state.reconciliation == .pendingUnlink)
        let nextGeneration = try await restarted.snapshot().generation
        do {
            _ = try await restarted.prepareMutation(.rotateRecoveryCodes, generation: nextGeneration)
            Issue.record("Prepared marker did not lock writes")
        } catch SessionFailure.storage {} catch { Issue.record("Wrong lock failure") }
        #expect(await store.value == .managed(persisted))
        #expect(dispatch.starts == 0)
    }

    @Test func failedAndAmbiguousPrepareNeverDispatch() async throws {
        for fault in ["write", "after-write", "readback"] {
            let store = MemorySessionStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
            let session = SessionCoordinator(store: store, authentication: SessionLoginFake())
            await session.restore()
            let generation = try await session.snapshot().generation
            if fault == "write" { await store.configure(write: true) }
            if fault == "after-write" { await store.configureMarkerFault(afterWrite: true) }
            if fault == "readback" { await store.configureMarkerFault(readBack: true) }
            let probe = MarkerDispatchProbe()
            do {
                let lease = try await session.prepareMutation(.unlinkGoogle, generation: generation)
                try await session.dispatchPrepared(lease) { probe.start() }
                Issue.record("Fault must prevent mutation dispatch")
            } catch SessionFailure.storage {} catch { Issue.record("Wrong storage failure") }
            #expect(probe.starts == 0)
            #expect(await session.state.reconciliation == .storageBlocked)
            let restarted = SessionCoordinator(store: store, authentication: SessionLoginFake())
            await restarted.restore()
            #expect(await restarted.state.reconciliation == (fault == "write" ? .clean : .pendingUnlink))
        }
    }

    @Test func clearFailureAndOldLeaseCannotUnlockNewSession() async throws {
        let store = MemorySessionStore(.managed(ActiveSessionRecord(token: "same-dummy-jwt")))
        let session = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await session.restore()
        let generation = try await session.snapshot().generation
        let lease = try await session.prepareMutation(.rotateRecoveryCodes, generation: generation)
        await store.configure(write: true)
        do {
            try await session.clearMutation(lease, resolution: .codesAcknowledged)
            Issue.record("Clear failure unlocked mutation")
        } catch SessionFailure.storage {} catch { Issue.record("Wrong clear failure") }
        #expect(await session.state.reconciliation == .storageBlocked)
        let restarted = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await restarted.restore()
        #expect(await restarted.state.reconciliation == .pendingRotation)

        await store.configure()
        #expect(await session.logout())
        try await session.authenticate { "same-dummy-jwt" }
        #expect(await session.state.reconciliation == .clean)
        do {
            try await session.clearMutation(lease, resolution: .codesAcknowledged)
            Issue.record("Old marker cleared a replacement session")
        } catch SessionFailure.stale {} catch { Issue.record("Wrong stale marker failure") }
        guard case .managed(let fresh) = await store.value else { Issue.record("Missing replacement record"); return }
        #expect(fresh.sessionID != lease.sessionID && fresh.marker == nil)
    }

    @Test func staleLastMethodClearCannotReplaceNewSessionMarker() async throws {
        let store = MemorySessionStore(.managed(ActiveSessionRecord(token: "same-dummy-jwt")))
        let session = SessionCoordinator(store: store, authentication: SessionLoginFake())
        await session.restore()
        let old = try await session.prepareMutation(.unlinkGoogle, generation: session.snapshot().generation)
        #expect(await session.logout())
        try await session.authenticate { "same-dummy-jwt" }
        let new = try await session.prepareMutation(.unlinkGoogle, generation: session.snapshot().generation)
        do {
            try await session.clearMutation(old, resolution: .lastMethodRejected)
            Issue.record("Stale 409 cleared replacement marker")
        } catch SessionFailure.stale {} catch { Issue.record("Wrong stale clear failure") }
        guard case .managed(let persisted) = await store.value else { Issue.record("Missing replacement record"); return }
        #expect(persisted.sessionID == new.sessionID && persisted.marker == new.marker)
        #expect(await session.state.reconciliation == .pendingUnlink)
    }
}

private actor ResponseGate {
    static let shared = ResponseGate()
    private var pending: [String: SessionHTTPStub] = [:]
    func register(_ stub: SessionHTTPStub, id: String) { pending[id] = stub }
    func contains(_ id: String) -> Bool { pending[id] != nil }
    func respond(_ id: String, status: Int) { pending.removeValue(forKey: id)?.respond(status) }
}

private final class SessionHTTPStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        if path.hasPrefix("/deferred/") {
            Task { await ResponseGate.shared.register(self, id: path) }
        } else if path == "/offline" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        } else {
            respond(Int(path.dropFirst()) ?? 200)
        }
    }
    func respond(_ status: Int) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        // Echoing the synthetic credential lets the test verify the atomic Bearer snapshot.
        client?.urlProtocol(self, didLoad: Data((request.value(forHTTPHeaderField: "Authorization") ?? "missing").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private actor ConstructionRaceAuthority: SessionAuthorizing {
    var isValid = true
    var started = false
    func snapshot(expectedGeneration: UInt64?) -> SessionSnapshot {
        isValid = false // Simulate replacement between snapshot and dispatch.
        return SessionSnapshot(token: "old-session", generation: 1)
    }
    func isCurrent(_ generation: UInt64) -> Bool { isValid }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) throws {
        guard isValid else { throw SessionFailure.stale }
        started = true
        start()
    }
    func unauthorized(_ generation: UInt64) -> Bool { false }
    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws { throw SessionFailure.storage }
}

@MainActor
struct SessionTransportTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionHTTPStub.self]
        return URLSession(configuration: configuration)
    }
    private func request(_ path: String) -> URLRequest { URLRequest(url: URL(string: "https://session.test\(path)")!) }

    @Test func realProtectedRequestUsesRestoredTokenAndNetworkFailurePreservesSession() async throws {
        let coordinator = SessionCoordinator(store: MemorySessionStore(.active("opaque-session")), authentication: SessionLoginFake())
        await coordinator.restore()
        let transport = AuthenticatedTransport(authority: coordinator, session: session())
        let (body, _) = try await transport.data(for: request("/200"))
        #expect(String(data: body, encoding: .utf8) == "Bearer opaque-session")
        let (_, response) = try await transport.data(for: request("/503"))
        #expect(response.statusCode == 503)
        do { _ = try await transport.data(for: request("/offline")); Issue.record("Expected offline error") } catch {}
        #expect(await coordinator.state.phase == .authenticated)
    }

    @Test func current401InvalidatesAndDoesNotReplay() async throws {
        let login = SessionLoginFake()
        let store = MemorySessionStore(.active("session-A"))
        let coordinator = SessionCoordinator(store: store, authentication: login)
        await coordinator.restore()
        let (_, response) = try await AuthenticatedTransport(authority: coordinator, session: session()).data(for: request("/401"))
        #expect(response.statusCode == 401)
        #expect(await coordinator.state.reason == .expired)
        #expect(await login.calls == 0)
        #expect(await store.writes == [.signedOut])
    }

    @Test func oldSuccessAndOld401CannotReachReplacementAccount() async throws {
        for status in [200, 401] {
            let coordinator = SessionCoordinator(store: MemorySessionStore(.active("session-A")), authentication: SessionLoginFake())
            await coordinator.restore()
            let generation = try await coordinator.snapshot().generation
            let transport = AuthenticatedTransport(authority: coordinator, generation: generation, session: session())
            let path = "/deferred/\(UUID().uuidString)"
            let pending = Task { try await transport.data(for: request(path)) }
            while !(await ResponseGate.shared.contains(path)) { await Task.yield() }
            try await coordinator.switchAccount(username: "fixture", password: "fixture")
            await ResponseGate.shared.respond(path, status: status)
            do { _ = try await pending.value; Issue.record("Old response must not reach a feature/cache") }
            catch SessionFailure.stale {} catch { Issue.record("Wrong stale response error") }
            #expect(try await coordinator.snapshot().token == "session-B")
            #expect(await coordinator.state.phase == .authenticated)
            // Even a new request from A's feature graph cannot borrow B's token.
            do { _ = try await transport.data(for: request("/200")); Issue.record("Old graph must not dispatch") }
            catch SessionFailure.stale {} catch { Issue.record("Wrong old graph error") }
        }
    }

    @Test func replacementDuringConstructionPreventsDispatch() async {
        let authority = ConstructionRaceAuthority()
        let transport = AuthenticatedTransport(authority: authority, session: session())
        do { _ = try await transport.data(for: request("/200")); Issue.record("Expected stale construction") }
        catch SessionFailure.stale {} catch { Issue.record("Wrong construction error") }
        #expect(!(await authority.started))
    }
}

@MainActor
struct KeychainMigrationTests {
    private func cleanup(service: String, defaults: UserDefaults) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "active-session",
            kSecAttrSynchronizable as String: false]
        let status = SecItemDelete(query as CFDictionary)
        #expect(status == errSecSuccess || status == errSecItemNotFound)
        defaults.removePersistentDomain(forName: service)
    }

    @Test func importsLegacyOnceAndSecureValueWins() async throws {
        let namespace = "kvx.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: namespace))
        defer { cleanup(service: namespace, defaults: defaults) }
        let store = KeychainSessionStore(defaults: defaults, service: namespace)
        defaults.set("legacy-fixture", forKey: "binblog.accessToken")
        #expect(try await store.read() == .active("legacy-fixture"))
        #expect(defaults.string(forKey: "binblog.accessToken") == nil)
        defaults.set("stale-fixture", forKey: "binblog.accessToken")
        #expect(try await store.read() == .active("legacy-fixture"))
    }

    @Test func signedOutSecureValueForbidsLegacyReimport() async throws {
        let namespace = "kvx.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: namespace))
        defer { cleanup(service: namespace, defaults: defaults) }
        let store = KeychainSessionStore(defaults: defaults, service: namespace)
        try await store.write(.signedOut)
        defaults.set("stale-fixture", forKey: "binblog.accessToken")
        #expect(try await store.read() == .signedOut)
        #expect(defaults.string(forKey: "binblog.accessToken") == nil)
    }

    @Test func fallbackDeleteRetainsSentinelAndForbidsLegacyReimport() async throws {
        let namespace = "kvx.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: namespace))
        defer { cleanup(service: namespace, defaults: defaults) }
        let store = KeychainSessionStore(defaults: defaults, service: namespace)
        try await store.write(.active("old-fixture"))
        try await store.delete()
        defaults.set("legacy-fixture", forKey: "binblog.accessToken")
        let restarted = KeychainSessionStore(defaults: defaults, service: namespace)
        #expect(try await restarted.read() == .signedOut)
        #expect(defaults.string(forKey: "binblog.accessToken") == nil)
    }

    @Test func realKeychainSupportsLogoutReloginAndRestartBarriers() async throws {
        let namespace = "kvx.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: namespace))
        defer { cleanup(service: namespace, defaults: defaults) }

        let login = SessionLoginFake()
        let coordinator = SessionCoordinator(
            store: KeychainSessionStore(defaults: defaults, service: namespace),
            authentication: login
        )
        await coordinator.restore()
        try await coordinator.login(username: "fixture", password: "fixture")
        #expect(try await coordinator.snapshot().token == "session-B")

        #expect(await coordinator.logout())
        #expect(await coordinator.state.phase == .signedOut)
        try await coordinator.login(username: "fixture", password: "fixture")

        let restored = SessionCoordinator(
            store: KeychainSessionStore(defaults: defaults, service: namespace),
            authentication: login
        )
        await restored.restore()
        #expect(try await restored.snapshot().token == "session-B")

        #expect(await restored.logout())
        let signedOutRestart = SessionCoordinator(
            store: KeychainSessionStore(defaults: defaults, service: namespace),
            authentication: login
        )
        await signedOutRestart.restore()
        #expect(await signedOutRestart.state.phase == .signedOut)
        #expect(await signedOutRestart.state.message == nil)
    }

    @Test func v2KeychainRecordHasStrictAllowlistAndInvalidMarkerIsQuarantined() async throws {
        let namespace = "kvx.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: namespace))
        defer { cleanup(service: namespace, defaults: defaults) }
        let store = KeychainSessionStore(defaults: defaults, service: namespace)
        let record = ActiveSessionRecord(token: "dummy-jwt", marker: ReconciliationMarker(operation: .unlinkGoogle))
        try await store.write(.managed(record))
        #expect(try await store.read() == .managed(record))
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: namespace, kSecAttrAccount as String: "active-session",
            kSecAttrSynchronizable as String: false]
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        #expect(SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess)
        let data = try #require(item as? Data)
        let map = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(map.keys) == Set(["version", "state", "token", "session_id", "marker"]))
        let marker = try #require(map["marker"] as? [String: Any])
        #expect(Set(marker.keys) == Set(["version", "operation_id", "operation", "provider", "reason"]))
        #expect(marker["provider"] as? String == "google")
        #expect(data.range(of: Data("dummy-password".utf8)) == nil)
        #expect(data.range(of: Data("dummy-grant".utf8)) == nil)

        var invalid = map
        var invalidMarker = marker
        invalidMarker["reason"] = "other"
        invalid["marker"] = invalidMarker
        let invalidData = try JSONSerialization.data(withJSONObject: invalid)
        let update: [String: Any] = [kSecValueData as String: invalidData]
        #expect(SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess)
        #expect(try await store.read() == .quarantined("dummy-jwt"))
        invalidMarker["reason"] = "await_provider_absence"
        invalidMarker["provider"] = "other"
        invalid["marker"] = invalidMarker
        let wrongProviderData = try JSONSerialization.data(withJSONObject: invalid)
        #expect(SecItemUpdate(query as CFDictionary,
                              [kSecValueData as String: wrongProviderData] as CFDictionary) == errSecSuccess)
        #expect(try await store.read() == .quarantined("dummy-jwt"))
        let floatVersionData = Data("""
        {"version":2,"state":"active","token":"dummy-jwt","session_id":"\(record.sessionID)","marker":{"version":1.0,"operation_id":"\(record.marker!.operationID)","operation":"unlink_google","provider":"google","reason":"await_provider_absence"}}
        """.utf8)
        #expect(SecItemUpdate(query as CFDictionary,
                              [kSecValueData as String: floatVersionData] as CFDictionary) == errSecSuccess)
        #expect(try await store.read() == .quarantined("dummy-jwt"))
    }
}

private final class PIRSessionHTTPStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let valid = request.value(forHTTPHeaderField: "Authorization") == "Bearer pir-fixture"
        let body: String
        if request.url?.path.hasSuffix("motion_heatmap") == true {
            body = #"{"data":[{"date":"2026-09-28","count":0}]}"#
        } else {
            body = "{\"date\":\"2026-09-28\",\"values\":[\(Array(repeating: "0", count: 24).joined(separator: ","))],\"total\":0}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: valid ? 200 : 401, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct PIRSessionTransportTests {
    @Test func bothPIRReadsUseTheCoordinatorsActiveJWT() async throws {
        let coordinator = SessionCoordinator(store: MemorySessionStore(.active("pir-fixture")), authentication: SessionLoginFake())
        await coordinator.restore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PIRSessionHTTPStub.self]
        let client = PIRAPIClient(transport: AuthenticatedTransport(authority: coordinator, session: URLSession(configuration: configuration)))
        #expect(try await client.statistics(chipID: "pir", date: "2026-09-28").total == 0)
        #expect(try await client.heatmap(chipID: "pir").count == 1)
    }
}

private actor DeviceGraphResponseGate {
    static let shared = DeviceGraphResponseGate()
    private var pending: [String: DeviceGraphHTTPStub] = [:]
    func register(_ stub: DeviceGraphHTTPStub, authorization: String) { pending[authorization] = stub }
    func contains(_ authorization: String) -> Bool { pending[authorization] != nil }
    func release(_ authorization: String, status: Int) { pending.removeValue(forKey: authorization)?.respond(status, name: "Account A device") }
}

private final class DeviceGraphHTTPStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let authorization = request.value(forHTTPHeaderField: "Authorization") ?? ""
        if authorization.hasPrefix("Bearer session-A-") {
            Task { await DeviceGraphResponseGate.shared.register(self, authorization: authorization) }
        } else if authorization == "Bearer session-B" {
            respond(200, name: "Account B device")
        } else { respond(401, name: "Unexpected credential") }
    }
    func respond(_ status: Int, name: String) {
        let body = "{\"devices\":[{\"id\":64,\"name\":\"\(name)\",\"chip_id\":\"fixture\",\"device_type\":\"pir\",\"status\":1}]}"
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct DeviceSessionGraphTests {
    @Test func oldDeviceGraphCannotReceiveLateSuccessOrInvalidateReplacement() async throws {
        for status in [200, 401] {
            let tokenA = "session-A-\(UUID().uuidString)"
            let coordinator = SessionCoordinator(store: MemorySessionStore(.active(tokenA)), authentication: SessionLoginFake())
            await coordinator.restore()
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [DeviceGraphHTTPStub.self]
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let oldGeneration = try await coordinator.snapshot().generation
            let transportA = AuthenticatedTransport(authority: coordinator, generation: oldGeneration, session: session)
            let modelA = DeviceViewModel(repository: RemoteDeviceRepository(dataSource: BinblogDeviceDataSource(transport: transportA)))
            let pendingA = Task { await modelA.loadDevices() }
            while !(await DeviceGraphResponseGate.shared.contains("Bearer \(tokenA)")) { await Task.yield() }
            try await coordinator.switchAccount(username: "fixture", password: "fixture")
            let generationB = try await coordinator.snapshot().generation
            let transportB = AuthenticatedTransport(authority: coordinator, generation: generationB, session: session)
            let modelB = DeviceViewModel(repository: RemoteDeviceRepository(dataSource: BinblogDeviceDataSource(transport: transportB)))
            await modelB.loadDevices()
            #expect(modelB.devices.map(\.name) == ["Account B device"])
            await DeviceGraphResponseGate.shared.release("Bearer \(tokenA)", status: status)
            await pendingA.value
            #expect(modelA.devices.isEmpty)
            #expect(modelB.devices.map(\.name) == ["Account B device"])
            #expect(!modelB.needsLogin && modelB.errorMessage == nil)
            #expect(await coordinator.state.phase == .authenticated)
            // A fresh operation on the disposed generation must fail before dispatch.
            await modelA.loadDevices()
            #expect(modelA.devices.isEmpty)
            #expect(modelB.devices.map(\.name) == ["Account B device"])
        }
    }
}
