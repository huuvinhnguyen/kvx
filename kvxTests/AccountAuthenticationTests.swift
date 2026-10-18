import Foundation
import Testing
@testable import kvx

private actor AccountTestAuthority: SessionAuthorizing {
    var current = true
    var expired = 0
    private let recordID = "11111111-1111-4111-8111-111111111111"
    private var marker: ReconciliationMarker?
    func snapshot(expectedGeneration: UInt64?) throws -> SessionSnapshot {
        guard current, expectedGeneration == 7 else { throw SessionFailure.stale }
        return SessionSnapshot(token: "dummy-binblog-session", generation: 7)
    }
    func isCurrent(_ generation: UInt64) -> Bool { current && generation == 7 }
    func dispatch(_ generation: UInt64, start: @Sendable () -> Void) throws {
        guard isCurrent(generation) else { throw SessionFailure.stale }
        start()
    }
    func unauthorized(_ generation: UInt64) -> Bool {
        guard isCurrent(generation) else { return false }
        expired += 1
        current = false
        return true
    }
    func switchAccount() { current = false }
    func reconciliationGate(_ generation: UInt64) async throws -> ReconciliationGate {
        guard isCurrent(generation) else { throw SessionFailure.stale }
        return .from(marker)
    }
    func refreshReconciliation(_ generation: UInt64) async throws -> ReconciliationGate {
        try await reconciliationGate(generation)
    }
    func prepareMutation(_ operation: ReconciliationOperation, generation: UInt64) async throws -> MutationLease {
        guard isCurrent(generation), marker == nil else { throw SessionFailure.storage }
        let created = ReconciliationMarker(operation: operation)
        marker = created
        return MutationLease(generation: generation, sessionID: recordID, marker: created)
    }
    func pendingMutation(_ generation: UInt64) async throws -> MutationLease? {
        guard isCurrent(generation) else { throw SessionFailure.stale }
        return marker.map { MutationLease(generation: generation, sessionID: recordID, marker: $0) }
    }
    func clearMutation(_ lease: MutationLease, resolution: MarkerResolution) async throws {
        guard isCurrent(lease.generation), lease.sessionID == recordID,
              marker == lease.marker else { throw SessionFailure.stale }
        marker = nil
    }
    func dispatchPrepared(_ lease: MutationLease, start: @Sendable () -> Void) async throws {
        guard isCurrent(lease.generation), lease.sessionID == recordID,
              marker == lease.marker else { throw SessionFailure.stale }
        start()
    }
}

private final class AccountTestProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "khuonvien.vn"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else { return }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func json(_ text: String) -> Data { Data(text.utf8) }
private func requestBody(_ request: URLRequest) -> [String: String] {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 1024)
        while data.count < 4096 {
            let count = buffer.withUnsafeMutableBufferPointer {
                stream.read($0.baseAddress!, maxLength: $0.count)
            }
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
    return (try? JSONSerialization.jsonObject(with: data) as? [String: String]) ?? [:]
}
private final class AccountRequestCapture: @unchecked Sendable {
    struct Fact {
        let url: String?
        let method: String?
        let hasDummyBearer: Bool
        let hasJSONContentType: Bool
        let bodyMatches: Bool
    }
    private let lock = NSLock()
    private var values: [Fact] = []
    private var methodReads = 0

    @discardableResult
    func record(_ request: URLRequest, body expected: [String: String]? = nil) -> Int {
        let fact = Fact(url: request.url?.absoluteString, method: request.httpMethod,
            hasDummyBearer: request.value(forHTTPHeaderField: "Authorization") == "Bearer dummy-binblog-session",
            hasJSONContentType: request.value(forHTTPHeaderField: "Content-Type") == "application/json",
            bodyMatches: expected.map { requestBody(request) == $0 } ?? true)
        lock.lock(); defer { lock.unlock() }
        values.append(fact)
        if request.httpMethod == "GET", request.url?.path == "/api/auth/methods" { methodReads += 1 }
        return methodReads
    }

    func facts() -> [Fact] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
}
private func accountClient(_ authority: AccountTestAuthority) -> AuthManagementClient {
    let config = AuthManagementClient.makeConfiguration()
    config.protocolClasses = [AccountTestProtocol.self]
    return AuthManagementClient(authority: authority, generation: 7, configuration: config)
}
private func accountClient(_ authority: any SessionAuthorizing, generation: UInt64) -> AuthManagementClient {
    let config = AuthManagementClient.makeConfiguration()
    config.protocolClasses = [AccountTestProtocol.self]
    return AuthManagementClient(authority: authority, generation: generation, configuration: config)
}

private actor AccountMarkerStore: SessionStore {
    var value: StoredSession?
    var failMarkedWrite = false
    var failMarkerClear = false
    init(_ value: StoredSession) { self.value = value }
    func rejectMarkedWrites() { failMarkedWrite = true }
    func rejectMarkerClear() { failMarkerClear = true }
    func read() -> StoredSession? { value }
    func write(_ next: StoredSession) throws {
        if failMarkedWrite, case .managed(let record) = next, record.marker != nil { throw SessionFailure.storage }
        if failMarkerClear, case .managed(let record) = next, record.marker == nil { throw SessionFailure.storage }
        value = next
    }
    func delete() { value = nil }
}

private actor AccountMarkerLogin: PasswordAuthenticating {
    func login(username: String, password: String) -> String { "dummy-jwt" }
}

private actor AccountRepositoryFake: AccountAuthRepository {
    var value = AuthenticationMethods(passwordUsable: true,
        providers: [ProviderMethod(provider: "google", usable: true, canUnlink: true)], codesEnrolled: false)
    var reauthCalls = 0
    var rotateCalls = 0
    var unlinkCalls = 0
    var failMutation = false
    var failMethods = false
    var retainGoogleOnUnlink = false
    var pauseMethods = false
    var pendingMethods: CheckedContinuation<AuthenticationMethods, Error>?
    var pauseReauth = false
    var pendingReauth: CheckedContinuation<ReauthenticationGrant, Error>?
    var pauseMutation = false
    var pendingMutation: CheckedContinuation<Void, Error>?
    var pauseBeforeDispatch = false
    var pendingBeforeDispatch: CheckedContinuation<Void, Error>?
    func configure(failMutation: Bool = false, failMethods: Bool = false) {
        self.failMutation = failMutation
        self.failMethods = failMethods
    }
    func keepGoogleAfterUnlink() { retainGoogleOnUnlink = true }
    func pauseNextMethods() { pauseMethods = true }
    func hasPendingMethods() -> Bool { pendingMethods != nil }
    func resumeMethods() { pendingMethods?.resume(returning: value); pendingMethods = nil }
    func pauseNextReauth() { pauseReauth = true }
    func hasPendingReauth() -> Bool { pendingReauth != nil }
    func resumeReauth() {
        pendingReauth?.resume(returning: ReauthenticationGrant(token: "dummy-grant", expiresAt: Date().addingTimeInterval(240), purpose: .rotateRecoveryCodes))
        pendingReauth = nil
    }
    func pauseNextMutation() { pauseMutation = true }
    func hasPendingMutation() -> Bool { pendingMutation != nil }
    func resumeMutation() { pendingMutation?.resume(); pendingMutation = nil }
    func pauseNextBeforeDispatch() { pauseBeforeDispatch = true }
    func hasPendingBeforeDispatch() -> Bool { pendingBeforeDispatch != nil }
    func resumeBeforeDispatch() { pendingBeforeDispatch?.resume(); pendingBeforeDispatch = nil }
    func methods() async throws -> AuthenticationMethods {
        if pauseMethods {
            pauseMethods = false
            return try await withCheckedThrowingContinuation { pendingMethods = $0 }
        }
        if failMethods { throw AccountAuthFailure.network }
        return value
    }
    func reauthenticate(password: String, purpose: ReauthenticationPurpose) async throws -> ReauthenticationGrant {
        reauthCalls += 1
        if pauseReauth {
            pauseReauth = false
            return try await withCheckedThrowingContinuation { pendingReauth = $0 }
        }
        return ReauthenticationGrant(token: "dummy-grant", expiresAt: Date().addingTimeInterval(240), purpose: purpose)
    }
    func rotateCodes(grant: ReauthenticationGrant, lease: MutationLease, beginDispatch: @escaping @Sendable () -> Bool) async throws -> [String] {
        if pauseBeforeDispatch {
            pauseBeforeDispatch = false
            try await withCheckedThrowingContinuation { pendingBeforeDispatch = $0 }
        }
        guard beginDispatch() else { throw AccountAuthFailure.cancelled }
        rotateCalls += 1
        if pauseMutation {
            pauseMutation = false
            try await withCheckedThrowingContinuation { pendingMutation = $0 }
        }
        if failMutation { throw AccountAuthFailure.network }
        return (0..<10).map { "dummy-code-\($0)" }
    }
    func unlinkGoogle(grant: ReauthenticationGrant, lease: MutationLease, beginDispatch: @escaping @Sendable () -> Bool) async throws {
        if pauseBeforeDispatch {
            pauseBeforeDispatch = false
            try await withCheckedThrowingContinuation { pendingBeforeDispatch = $0 }
        }
        guard beginDispatch() else { throw AccountAuthFailure.cancelled }
        unlinkCalls += 1
        if pauseMutation {
            pauseMutation = false
            try await withCheckedThrowingContinuation { pendingMutation = $0 }
        }
        if failMutation { throw AccountAuthFailure.network }
        if !retainGoogleOnUnlink {
            value = AuthenticationMethods(passwordUsable: true, providers: [], codesEnrolled: false)
        }
    }
}

@Suite(.serialized)
struct AccountAuthenticationTests {
    @Test func methodsAndExactAuthenticatedRequest() async throws {
        let authority = AccountTestAuthority()
        AccountTestProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://khuonvien.vn/api/auth/methods")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer dummy-binblog-session")
            return (200, json(#"{"status":"success","password":{"usable":true},"providers":[{"provider":"google","usable":true,"can_unlink":true}],"recovery":{"codes_enrolled":false}}"#))
        }
        let methods = try await accountClient(authority).methods()
        #expect(methods.canUnlinkGoogle)
        #expect(!methods.codesEnrolled)
        AccountTestProtocol.handler = nil
    }

    @Test func onlyParsedCurrentAuthenticationRequiredExpires() async {
        for code in ["authentication_required", "invalid_provider_credential", "other"] {
            let authority = AccountTestAuthority()
            AccountTestProtocol.handler = { _ in (401, json("{\"status\":\"error\",\"code\":\"\(code)\"}")) }
            do { _ = try await accountClient(authority).methods(); Issue.record("Expected failure") }
            catch { #expect(error is AccountAuthFailure) }
            #expect(await authority.expired == (code == "authentication_required" ? 1 : 0))
        }
        let authority = AccountTestAuthority()
        AccountTestProtocol.handler = { _ in (401, json(#"{"status":"error","code":4}"#)) }
        do { _ = try await accountClient(authority).methods(); Issue.record("Expected failure") }
        catch { #expect(error as? AccountAuthFailure == .malformedResponse) }
        #expect(await authority.expired == 0)
        AccountTestProtocol.handler = nil
    }

    @Test func grantIsPurposeBoundExpiresAndCanOnlyBeConsumedOnce() {
        let grant = ReauthenticationGrant(token: "dummy", expiresAt: Date().addingTimeInterval(30), purpose: .unlinkIdentity)
        #expect(grant.consume(for: .rotateRecoveryCodes) == nil)
        #expect(grant.consume(for: .unlinkIdentity) != nil)
        #expect(grant.consume(for: .unlinkIdentity) == nil)
        let expired = ReauthenticationGrant(token: "dummy", expiresAt: Date().addingTimeInterval(-1), purpose: .unlinkIdentity)
        #expect(expired.consume(for: .unlinkIdentity) == nil)
    }

    @Test func passwordReauthenticationUsesExactMutationContract() async throws {
        let authority = AccountTestAuthority()
        let capture = AccountRequestCapture()
        AccountTestProtocol.handler = { request in
            capture.record(request, body: ["purpose": "rotate_recovery_codes", "method": "password", "password": "dummy-password"])
            return (200, json(#"{"status":"success","reauthentication_token":"dummy-grant","expires_at":"2099-01-01T00:00:00Z"}"#))
        }
        defer { AccountTestProtocol.handler = nil }
        let grant = try await accountClient(authority).reauthenticate(password: "dummy-password", purpose: .rotateRecoveryCodes)
        #expect(grant.usable(for: .rotateRecoveryCodes))
        #expect(!grant.usable(for: .unlinkIdentity))
        let facts = capture.facts()
        #expect(facts.count == 1)
        #expect(facts.first?.url == "https://khuonvien.vn/api/auth/reauthentications")
        #expect(facts.first?.method == "POST")
        #expect(facts.first?.hasDummyBearer == true)
        #expect(facts.first?.hasJSONContentType == true)
        #expect(facts.first?.bodyMatches == true)
    }

    @Test func recoveryCodeRotationUsesGrantOnceAndDecodesReceipt() async throws {
        let authority = AccountTestAuthority()
        let capture = AccountRequestCapture()
        AccountTestProtocol.handler = { request in
            capture.record(request, body: ["reauthentication_token": "dummy-grant"])
            let codes = (0..<10).map { "dummy-code-\($0)" }
            return (200, try! JSONSerialization.data(withJSONObject: ["status": "success", "code": "recovery_codes_rotated", "codes": codes]))
        }
        defer { AccountTestProtocol.handler = nil }
        let grant = ReauthenticationGrant(token: "dummy-grant", expiresAt: Date().addingTimeInterval(240), purpose: .rotateRecoveryCodes)
        let client = accountClient(authority)
        let lease: MutationLease
        do { lease = try await authority.prepareMutation(.rotateRecoveryCodes, generation: 7) }
        catch { Issue.record("Rotation marker preparation failed: \(type(of: error))"); return }
        let codes: [String]
        do { codes = try await client.rotateCodes(grant: grant, lease: lease, beginDispatch: { true }) }
        catch { Issue.record("Rotation transport failed: \(type(of: error))"); return }
        #expect(codes.count == 10)
        do { _ = try await client.rotateCodes(grant: grant, lease: lease, beginDispatch: { true }); Issue.record("Consumed grant replayed") }
        catch { #expect(error as? AccountAuthFailure == .reauthenticationRequired) }
        let facts = capture.facts()
        #expect(facts.count == 1)
        #expect(facts.first?.url == "https://khuonvien.vn/api/auth/recovery_codes")
        #expect(facts.first?.method == "POST")
        #expect(facts.first?.hasDummyBearer == true)
        #expect(facts.first?.hasJSONContentType == true)
        #expect(facts.first?.bodyMatches == true)
    }

    @Test func unlinkContractClassifiesSuccessAndFailuresWithoutWrongExpiry() async throws {
        for code in ["unlinked", "not_linked"] {
            let authority = AccountTestAuthority()
            let capture = AccountRequestCapture()
            AccountTestProtocol.handler = { request in
                capture.record(request, body: ["reauthentication_token": "dummy-grant"])
                return (200, json("{\"status\":\"success\",\"code\":\"\(code)\"}"))
            }
            let grant = ReauthenticationGrant(token: "dummy-grant", expiresAt: Date().addingTimeInterval(240), purpose: .unlinkIdentity)
            let lease: MutationLease
            do { lease = try await authority.prepareMutation(.unlinkGoogle, generation: 7) }
            catch { Issue.record("Unlink marker preparation failed: \(type(of: error))"); return }
            do { try await accountClient(authority).unlinkGoogle(grant: grant, lease: lease, beginDispatch: { true }) }
            catch { Issue.record("Unlink transport failed: \(type(of: error))"); return }
            #expect(await authority.expired == 0)
            let facts = capture.facts()
            #expect(facts.count == 1)
            #expect(facts.first?.url == "https://khuonvien.vn/api/auth/social_identities/google")
            #expect(facts.first?.method == "DELETE")
            #expect(facts.first?.hasDummyBearer == true)
            #expect(facts.first?.hasJSONContentType == true)
            #expect(facts.first?.bodyMatches == true)
        }
        let failures: [(Int, String, AccountAuthFailure, Int)] = [
            (403, "reauthentication_required", .reauthenticationRequired, 0),
            (409, "last_authentication_method", .lastAuthenticationMethod, 0),
            (422, "unsupported_provider", .unsupportedProvider, 0),
            (500, "internal_error", .serverFailure, 0),
            (401, "invalid_provider_credential", .invalidProviderCredential, 0),
            (401, "authentication_required", .authenticationRequired, 1)
        ]
        for (status, code, expectedFailure, expectedExpiry) in failures {
            let authority = AccountTestAuthority()
            let capture = AccountRequestCapture()
            AccountTestProtocol.handler = { request in
                capture.record(request, body: ["reauthentication_token": "dummy-grant"])
                return (status, json("{\"status\":\"error\",\"code\":\"\(code)\"}"))
            }
            let grant = ReauthenticationGrant(token: "dummy-grant", expiresAt: Date().addingTimeInterval(240), purpose: .unlinkIdentity)
            let lease = try await authority.prepareMutation(.unlinkGoogle, generation: 7)
            do { try await accountClient(authority).unlinkGoogle(grant: grant, lease: lease, beginDispatch: { true }); Issue.record("Expected failure") }
            catch { #expect(error as? AccountAuthFailure == expectedFailure) }
            #expect(await authority.expired == expectedExpiry)
            let facts = capture.facts()
            #expect(facts.count == 1)
            #expect(facts.first?.url == "https://khuonvien.vn/api/auth/social_identities/google")
            #expect(facts.first?.method == "DELETE")
            #expect(facts.first?.hasDummyBearer == true)
            #expect(facts.first?.bodyMatches == true)
        }
        AccountTestProtocol.handler = nil
    }

    @Test func stableOperationFailuresNeverExpireBinblog() async {
        let fixtures: [(Int, String, AccountAuthFailure)] = [
            (400, "malformed_request", .malformedRequest),
            (403, "reauthentication_failed", .reauthenticationFailed),
            (403, "reauthentication_required", .reauthenticationRequired),
            (409, "last_authentication_method", .lastAuthenticationMethod),
            (422, "unsupported_method", .unsupportedMethod),
            (422, "unsupported_provider", .unsupportedProvider),
            (429, "rate_limited", .rateLimited),
            (503, "provider_unavailable", .providerUnavailable),
            (500, "internal_error", .serverFailure),
        ]
        for (status, code, expected) in fixtures {
            let authority = AccountTestAuthority()
            AccountTestProtocol.handler = { _ in (status, json("{\"status\":\"error\",\"code\":\"\(code)\"}")) }
            do {
                _ = try await accountClient(authority).reauthenticate(password: "dummy-password", purpose: .rotateRecoveryCodes)
                Issue.record("Expected failure")
            } catch { #expect(error as? AccountAuthFailure == expected) }
            #expect(await authority.expired == 0)
        }
        AccountTestProtocol.handler = nil
    }

    @Test func malformedMethodsProjectionPreservesSession() async {
        let authority = AccountTestAuthority()
        AccountTestProtocol.handler = { _ in
            (200, json(#"{"status":"success","password":{"usable":"yes"},"providers":[],"recovery":{"codes_enrolled":false}}"#))
        }
        do { _ = try await accountClient(authority).methods(); Issue.record("Expected failure") }
        catch { #expect(error as? AccountAuthFailure == .malformedResponse) }
        #expect(await authority.expired == 0)
        AccountTestProtocol.handler = nil
    }

    @Test func lateAuthenticationRequiredFromOldGenerationIsDiscarded() async {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let authority = AccountTestAuthority()
        AccountTestProtocol.handler = { _ in
            entered.signal()
            _ = release.wait(timeout: .now() + 3)
            return (401, json(#"{"status":"error","code":"authentication_required"}"#))
        }
        let pending = Task { try await accountClient(authority).methods() }
        let entry = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: entered.wait(timeout: .now() + 3))
            }
        }
        #expect(entry == .success)
        await authority.switchAccount()
        release.signal()
        do { _ = try await pending.value; Issue.record("Expected stale response") }
        catch { #expect(error as? AccountAuthFailure == .stale) }
        #expect(await authority.expired == 0)
        AccountTestProtocol.handler = nil
    }

    @Test func bodyLimitIsAppliedWhileReceivingWithoutContentLengthTrust() async throws {
        let authority = AccountTestAuthority()
        let body = json(#"{"status":"success","password":{"usable":true},"providers":[],"recovery":{"codes_enrolled":false}}"#)
        let exact = body + Data(repeating: 0x20, count: 16 * 1024 - body.count)
        AccountTestProtocol.handler = { _ in (200, exact) }
        _ = try await accountClient(authority).methods()
        AccountTestProtocol.handler = { _ in (200, exact + Data([0x20])) }
        do { _ = try await accountClient(authority).methods(); Issue.record("Expected body limit") }
        catch { #expect(error as? AccountAuthFailure == .malformedResponse) }
        #expect(await authority.expired == 0)
        AccountTestProtocol.handler = nil
    }

    @Test @MainActor func rotationIsSingleOperationAndCodesClear() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        #expect(!model.writeInFlight)
        await settle(model)
        model.rotate(password: "dummy-password")
        #expect(model.writeInFlight)
        model.rotate(password: "dummy-password")
        await settle(model)
        #expect(!model.writeInFlight)
        #expect(await repository.reauthCalls == 1)
        #expect(await repository.rotateCalls == 1)
        #expect(model.codes.count == 10)
        model.acknowledgeCodes()
        #expect(model.codes.isEmpty)
        model.cancel()
    }

    @Test @MainActor func uncertainRotationAndFailedReconciliationBlockWrites() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        await repository.configure(failMutation: true, failMethods: true)
        model.rotate(password: "dummy-password")
        await settle(model)
        #expect(model.lostCodes)
        #expect(model.writeBlocked)
        #expect(!model.canRotate)
        #expect(model.codes.isEmpty)
        model.cancel()
    }

    @Test @MainActor func cancellationClearsSecretsAndLateResultCannotPublish() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        model.rotate(password: "dummy-password")
        await settle(model)
        #expect(!model.codes.isEmpty)
        await repository.pauseNextMethods()
        model.refresh()
        for _ in 0..<1000 {
            if await repository.hasPendingMethods() { break }
            await Task.yield()
        }
        #expect(await repository.hasPendingMethods())
        await authority.switchAccount()
        model.cancel()
        await repository.resumeMethods()
        await Task.yield()
        #expect(model.codes.isEmpty)
        #expect(model.methods == nil)
        #expect(!model.busy)
    }

    @Test @MainActor func unlinkReconcilesAndUncertainUnlinkDoesNotReplay() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        model.unlink(password: "dummy-password")
        await settle(model)
        #expect(await repository.unlinkCalls == 1)
        #expect(model.methods?.providers.isEmpty == true)
        model.cancel()

        let uncertain = AccountRepositoryFake()
        let another = AccountMethodsViewModel(repository: uncertain, authority: authority, generation: 7)
        another.refresh()
        await settle(another)
        await uncertain.configure(failMutation: true)
        another.unlink(password: "dummy-password")
        await settle(another)
        #expect(await uncertain.unlinkCalls == 1)
        #expect(another.methods?.canUnlinkGoogle == true)
        another.cancel()
    }

    @Test @MainActor func notLinkedReceiptReconcilesWithRealClient() async {
        defer { AccountTestProtocol.handler = nil }
        for providerRemains in [false, true] {
            let authority = AccountTestAuthority()
            let continuity = AccountMethodsContinuity(generation: 7)
            let capture = AccountRequestCapture()
            AccountTestProtocol.handler = { request in
                switch (request.httpMethod, request.url?.path) {
                case ("GET", "/api/auth/methods"):
                    let reads = capture.record(request)
                    if providerRemains && reads == 4 {
                        return (503, json(#"{"status":"error","code":"server_error"}"#))
                    }
                    if providerRemains && reads == 5 {
                        return (200, json(#"{"status":"success","password":{"usable":"yes"},"providers":[],"recovery":{"codes_enrolled":false}}"#))
                    }
                    let providers = reads == 1 || (providerRemains && reads < 6)
                        ? #"[{"provider":"google","usable":true,"can_unlink":true}]"# : "[]"
                    return (200, json("{\"status\":\"success\",\"password\":{\"usable\":true},\"providers\":\(providers),\"recovery\":{\"codes_enrolled\":false}}"))
                case ("POST", "/api/auth/reauthentications"):
                    capture.record(request, body: ["purpose": "unlink_identity", "method": "password", "password": "dummy-password"])
                    return (200, json(#"{"status":"success","reauthentication_token":"dummy-grant","expires_at":"2099-01-01T00:00:00Z"}"#))
                case ("DELETE", "/api/auth/social_identities/google"):
                    capture.record(request, body: ["reauthentication_token": "dummy-grant"])
                    return (200, json(#"{"status":"success","code":"not_linked"}"#))
                default:
                    capture.record(request)
                    return (400, json(#"{"status":"error","code":"malformed_request"}"#))
                }
            }
            var model = AccountMethodsViewModel(repository: accountClient(authority), authority: authority,
                                                generation: 7, continuity: continuity)
            model.refresh()
            await settle(model)
            #expect(model.canUnlink)
            model.unlink(password: "dummy-password")
            await settle(model)
            let facts = capture.facts()
            #expect(facts.count == 4)
            #expect(facts.filter { $0.method == "GET" && $0.url == "https://khuonvien.vn/api/auth/methods" }.count == 2)
            #expect(facts.filter { $0.method == "POST" }.first?.bodyMatches == true)
            #expect(facts.filter { $0.method == "DELETE" }.first?.bodyMatches == true)
            #expect((model.methods?.providers.isEmpty == false) == providerRemains)
            #expect(model.writeBlocked == providerRemains)
            #expect(!model.canUnlink)
            if providerRemains { #expect(model.message != "Đã cập nhật phương thức đăng nhập.") }
            if providerRemains {
                model.beginPrompt(.unlinkIdentity)
                model.password = "dummy-password"
                model.cancel()
                #expect(model.password.isEmpty && model.requested == nil && model.codes.isEmpty)
                #expect(continuity.writeBlocked)
                model = AccountMethodsViewModel(repository: accountClient(authority), authority: authority,
                                                 generation: 7, continuity: continuity)
                #expect(model.writeBlocked && !model.canUnlink)
                for expectedReads in [3, 4, 5] {
                    model.refresh()
                    await settle(model)
                    let currentFacts = capture.facts()
                    #expect(currentFacts.filter { $0.method == "GET" }.count == expectedReads)
                    #expect(model.methods?.providers.contains(where: { $0.provider == "google" }) == true)
                    #expect(model.writeBlocked && !model.canUnlink)
                    #expect(model.message != "Đã cập nhật phương thức đăng nhập.")
                    #expect(currentFacts.filter { $0.method == "DELETE" }.count == 1)
                }
                model.refresh()
                await settle(model)
                #expect(model.methods?.providers.contains(where: { $0.provider == "google" }) == false)
                #expect(!model.writeBlocked && !model.canUnlink)
                #expect(capture.facts().filter { $0.method == "GET" }.count == 6)
                #expect(capture.facts().filter { $0.method == "DELETE" }.count == 1)
            }
            model.cancel()
        }
    }

    @Test @MainActor func failedMarkerWriteSendsZeroDELETERequests() async throws {
        defer { AccountTestProtocol.handler = nil }
        let store = AccountMarkerStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
        await store.rejectMarkedWrites()
        let session = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
        await session.restore()
        let generation = try await session.snapshot().generation
        let capture = AccountRequestCapture()
        AccountTestProtocol.handler = { request in
            capture.record(request)
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/auth/methods"):
                return (200, json(#"{"status":"success","password":{"usable":true},"providers":[{"provider":"google","usable":true,"can_unlink":true}],"recovery":{"codes_enrolled":false}}"#))
            case ("POST", "/api/auth/reauthentications"):
                return (200, json(#"{"status":"success","reauthentication_token":"dummy-grant","expires_at":"2099-01-01T00:00:00Z"}"#))
            default: return (500, json(#"{"status":"error","code":"internal_error"}"#))
            }
        }
        let model = AccountMethodsViewModel(repository: accountClient(session, generation: generation),
                                            authority: session, generation: generation,
                                            continuity: AccountMethodsContinuity(generation: generation, gate: await session.state.reconciliation))
        model.refresh(); await settle(model)
        model.unlink(password: "dummy-password"); await settle(model)
        #expect(capture.facts().filter { $0.method == "DELETE" }.isEmpty)
        #expect(model.writeBlocked)
        #expect(await session.state.reconciliation == .storageBlocked)
        guard case .managed(let persisted) = await store.value else { Issue.record("Missing clean record"); return }
        #expect(persisted.marker == nil)
        model.cancel()
    }

    @Test @MainActor func lastMethodRejectionClearsOnlyAfterValidReadAndDurableClear() async throws {
        for outcome in ["valid", "server-error", "malformed", "clear-failure"] {
            defer { AccountTestProtocol.handler = nil }
            let store = AccountMarkerStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
            if outcome == "clear-failure" { await store.rejectMarkerClear() }
            let session = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
            await session.restore()
            let generation = try await session.snapshot().generation
            let capture = AccountRequestCapture()
            AccountTestProtocol.handler = { request in
                let reads = capture.record(request)
                switch (request.httpMethod, request.url?.path) {
                case ("GET", "/api/auth/methods"):
                    if reads == 2 && outcome == "server-error" { return (503, json(#"{"status":"error","code":"server_error"}"#)) }
                    if reads == 2 && outcome == "malformed" { return (200, json(#"{"status":"success","password":{"usable":"wrong"},"providers":[],"recovery":{"codes_enrolled":false}}"#)) }
                    return (200, json(#"{"status":"success","password":{"usable":true},"providers":[{"provider":"google","usable":true,"can_unlink":true}],"recovery":{"codes_enrolled":false}}"#))
                case ("POST", "/api/auth/reauthentications"):
                    return (200, json(#"{"status":"success","reauthentication_token":"dummy-grant","expires_at":"2099-01-01T00:00:00Z"}"#))
                case ("DELETE", "/api/auth/social_identities/google"):
                    return (409, json(#"{"status":"error","code":"last_authentication_method"}"#))
                default: return (500, json(#"{"status":"error","code":"internal_error"}"#))
                }
            }
            let model = AccountMethodsViewModel(repository: accountClient(session, generation: generation),
                authority: session, generation: generation,
                continuity: AccountMethodsContinuity(generation: generation, gate: await session.state.reconciliation))
            model.refresh(); await settle(model)
            model.unlink(password: "dummy-password"); await settle(model)
            let cleared = outcome == "valid"
            #expect(model.writeBlocked == !cleared)
            #expect(capture.facts().filter { $0.method == "DELETE" }.count == 1)
            #expect(model.message != "Đã cập nhật phương thức đăng nhập.")
            if cleared { #expect(model.message == AccountAuthFailure.lastAuthenticationMethod.localizedDescription) }
            else { #expect(model.message != "Binblog vẫn ghi nhận Google. Tải lại trạng thái trước khi thao tác tiếp." || model.writeBlocked) }
            guard case .managed(let record) = await store.value else { Issue.record("Missing session record"); return }
            #expect((record.marker == nil) == cleared)
            model.cancel()
        }
    }

    @Test @MainActor func preparedUnlinkWithoutDispatchRestoresLockedMethodsGraph() async throws {
        defer { AccountTestProtocol.handler = nil }
        let store = AccountMarkerStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
        let first = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
        await first.restore()
        let lease = try await first.prepareMutation(.unlinkGoogle, generation: first.snapshot().generation)
        guard case .managed(let prepared) = await store.value else { Issue.record("Missing prepared record"); return }
        #expect(prepared.marker == lease.marker)
        let capture = AccountRequestCapture()
        AccountTestProtocol.handler = { request in
            capture.record(request)
            return (200, json(#"{"status":"success","password":{"usable":true},"providers":[{"provider":"google","usable":true,"can_unlink":true}],"recovery":{"codes_enrolled":false}}"#))
        }
        let restored = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
        await restored.restore()
        let generation = try await restored.snapshot().generation
        let model = AccountMethodsViewModel(repository: accountClient(restored, generation: generation),
            authority: restored, generation: generation,
            continuity: AccountMethodsContinuity(generation: generation, gate: await restored.state.reconciliation))
        #expect(model.writeBlocked)
        model.refresh(); await settle(model)
        #expect(model.writeBlocked && !model.canUnlink)
        #expect(capture.facts().filter { $0.method == "GET" }.count == 1)
        #expect(capture.facts().filter { $0.method == "DELETE" }.count == 0)
        #expect(await store.value == .managed(prepared))
        model.cancel()
    }

    @Test @MainActor func durableUnlinkLockSurvivesNewCoordinatorUntilProviderAbsence() async throws {
        defer { AccountTestProtocol.handler = nil }
        let store = AccountMarkerStore(.managed(ActiveSessionRecord(token: "dummy-jwt")))
        let firstSession = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
        await firstSession.restore()
        let capture = AccountRequestCapture()
        AccountTestProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/auth/methods"):
                let reads = capture.record(request)
                if reads == 4 { return (503, json(#"{"status":"error","code":"server_error"}"#)) }
                if reads == 5 { return (200, json(#"{"status":"success","password":{"usable":"wrong"},"providers":[],"recovery":{"codes_enrolled":false}}"#)) }
                let providers = reads == 6 ? "[]" : #"[{"provider":"google","usable":true,"can_unlink":true}]"#
                return (200, json("{\"status\":\"success\",\"password\":{\"usable\":true},\"providers\":\(providers),\"recovery\":{\"codes_enrolled\":false}}"))
            case ("POST", "/api/auth/reauthentications"):
                capture.record(request)
                return (200, json(#"{"status":"success","reauthentication_token":"dummy-grant","expires_at":"2099-01-01T00:00:00Z"}"#))
            case ("DELETE", "/api/auth/social_identities/google"):
                capture.record(request)
                return (200, json(#"{"status":"success","code":"not_linked"}"#))
            default: return (400, json(#"{"status":"error","code":"malformed_request"}"#))
            }
        }
        let generation = try await firstSession.snapshot().generation
        let first = AccountMethodsViewModel(repository: accountClient(firstSession, generation: generation),
                                            authority: firstSession, generation: generation,
                                            continuity: AccountMethodsContinuity(generation: generation, gate: await firstSession.state.reconciliation))
        first.refresh(); await settle(first)
        first.unlink(password: "dummy-password"); await settle(first)
        #expect(first.writeBlocked)
        guard case .managed(let persisted) = await store.value else { Issue.record("Missing pending marker"); return }
        #expect(persisted.marker?.operation == .unlinkGoogle)
        first.cancel()

        let restarted = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
        await restarted.restore()
        let newGeneration = try await restarted.snapshot().generation
        let next = AccountMethodsViewModel(repository: accountClient(restarted, generation: newGeneration),
                                           authority: restarted, generation: newGeneration,
                                           continuity: AccountMethodsContinuity(generation: newGeneration, gate: await restarted.state.reconciliation))
        #expect(next.writeBlocked)
        for expected in [3, 4, 5] {
            next.refresh(); await settle(next)
            #expect(capture.facts().filter { $0.method == "GET" }.count == expected)
            #expect(next.writeBlocked && !next.canUnlink)
            #expect(capture.facts().filter { $0.method == "DELETE" }.count == 1)
        }
        next.refresh(); await settle(next)
        #expect(capture.facts().filter { $0.method == "GET" }.count == 6)
        #expect(capture.facts().filter { $0.method == "DELETE" }.count == 1)
        #expect(!next.writeBlocked)
        guard case .managed(let resolved) = await store.value else { Issue.record("Missing resolved record"); return }
        #expect(resolved.marker == nil)
        next.cancel()
    }

    @Test @MainActor func restoredRotationWarningNeedsValidReadAndExplicitAcknowledgement() async throws {
        defer { AccountTestProtocol.handler = nil }
        let record = ActiveSessionRecord(token: "dummy-jwt", marker: ReconciliationMarker(operation: .rotateRecoveryCodes))
        let store = AccountMarkerStore(.managed(record))
        let session = SessionCoordinator(store: store, authentication: AccountMarkerLogin())
        await session.restore()
        let generation = try await session.snapshot().generation
        let capture = AccountRequestCapture()
        AccountTestProtocol.handler = { request in
            let reads = capture.record(request)
            if reads == 1 { return (503, json(#"{"status":"error","code":"server_error"}"#)) }
            return (200, json(#"{"status":"success","password":{"usable":true},"providers":[],"recovery":{"codes_enrolled":true}}"#))
        }
        let model = AccountMethodsViewModel(repository: accountClient(session, generation: generation),
                                            authority: session, generation: generation,
                                            continuity: AccountMethodsContinuity(generation: generation, gate: await session.state.reconciliation))
        #expect(model.lostCodes && model.writeBlocked)
        model.refresh(); await settle(model)
        #expect(model.writeBlocked && !model.canAcknowledgeLostCodes)
        model.acknowledgeLostCodes()
        guard case .managed(let stillPending) = await store.value else { Issue.record("Missing rotation record"); return }
        #expect(stillPending.marker != nil)
        model.refresh(); await settle(model)
        #expect(model.codes.isEmpty && model.canAcknowledgeLostCodes && model.writeBlocked)
        model.acknowledgeLostCodes(); await settle(model)
        guard case .managed(let resolved) = await store.value else { Issue.record("Missing resolved rotation record"); return }
        #expect(resolved.marker == nil)
        #expect(!model.writeBlocked)
        #expect(capture.facts().allSatisfy { $0.method == "GET" })
        model.cancel()
    }

    @Test @MainActor func pendingUnlinkLateReadCannotChangeNextSession() async {
        let repository = AccountRepositoryFake()
        await repository.keepGoogleAfterUnlink()
        let oldAuthority = AccountTestAuthority()
        let oldContinuity = AccountMethodsContinuity(generation: 7)
        let old = AccountMethodsViewModel(repository: repository, authority: oldAuthority,
                                          generation: 7, continuity: oldContinuity)
        old.refresh()
        await settle(old)
        old.unlink(password: "dummy-password")
        await settle(old)
        #expect(old.writeBlocked && !old.canUnlink)
        await repository.pauseNextMethods()
        old.refresh()
        for _ in 0..<1000 {
            if await repository.hasPendingMethods() { break }
            await Task.yield()
        }
        #expect(await repository.hasPendingMethods())
        await oldAuthority.switchAccount()
        old.cancel()
        oldContinuity.invalidate()
        let newAuthority = AccountTestAuthority()
        let newer = AccountMethodsViewModel(repository: repository, authority: newAuthority,
                                            generation: 7, continuity: AccountMethodsContinuity(generation: 7))
        newer.refresh()
        await settle(newer)
        #expect(newer.canUnlink)
        await repository.resumeMethods()
        await Task.yield()
        #expect(old.methods == nil && !old.writeBlocked)
        #expect(newer.canUnlink && !newer.writeBlocked)
        #expect(await repository.unlinkCalls == 1)
        newer.cancel()
    }

    @Test @MainActor func lostRotationWarningSurvivesScreenRecreationWithoutCodes() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let continuity = AccountMethodsContinuity(generation: 7)
        let first = AccountMethodsViewModel(repository: repository, authority: authority,
                                            generation: 7, continuity: continuity)
        first.refresh()
        await settle(first)
        first.rotate(password: "dummy-password")
        await settle(first)
        #expect(!first.codes.isEmpty)
        first.cancel()
        #expect(first.codes.isEmpty && first.password.isEmpty)
        #expect(continuity.lostCodes && continuity.writeBlocked)
        let reopened = AccountMethodsViewModel(repository: repository, authority: authority,
                                               generation: 7, continuity: continuity)
        #expect(reopened.lostCodes && reopened.writeBlocked && !reopened.canRotate)
        reopened.refresh()
        await settle(reopened)
        #expect(reopened.lostCodes && reopened.writeBlocked && !reopened.canRotate)
        #expect(await repository.rotateCalls == 1)
        reopened.acknowledgeLostCodes()
        await settle(reopened)
        #expect(reopened.canRotate)
        reopened.cancel()
        continuity.invalidate()
        #expect(!continuity.lostCodes && !continuity.writeBlocked)
    }

    @Test @MainActor func backgroundClearsPasswordPromptWithoutDispatch() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        model.beginPrompt(.rotateRecoveryCodes)
        model.password = "dummy-password"
        model.suspendForPrivacy()
        #expect(model.privacySuspended)
        #expect(model.requested == nil)
        #expect(model.password.isEmpty)
        #expect(model.codes.isEmpty)
        model.resumeForPrivacy()
        #expect(await repository.reauthCalls == 0)
        #expect(await repository.rotateCalls == 0)
        model.cancel()
    }

    @Test @MainActor func backgroundClearsDisplayedCodesAndRequiresRefreshAndAcknowledgement() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        model.rotate(password: "dummy-password")
        await settle(model)
        #expect(model.codes.count == 10)
        model.suspendForPrivacy()
        #expect(model.codes.isEmpty)
        #expect(model.lostCodes && model.writeBlocked)
        model.resumeForPrivacy()
        #expect(!model.canRotate)
        model.refresh()
        await settle(model)
        #expect(model.writeBlocked && model.lostCodes)
        model.acknowledgeLostCodes()
        await settle(model)
        #expect(model.canRotate)
        #expect(await repository.rotateCalls == 1)
        model.cancel()
    }

    @Test @MainActor func backgroundBeforeMutationDispatchDoesNotInventUncertainWrite() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        await repository.pauseNextBeforeDispatch()
        model.rotate(password: "dummy-password")
        for _ in 0..<1000 {
            if await repository.hasPendingBeforeDispatch() { break }
            await Task.yield()
        }
        #expect(await repository.hasPendingBeforeDispatch())
        model.suspendForPrivacy()
        model.resumeForPrivacy()
        await repository.resumeBeforeDispatch()
        for _ in 0..<1000 {
            if !model.writeBlocked { break }
            await Task.yield()
        }
        #expect(await repository.rotateCalls == 0)
        #expect(!model.lostCodes && !model.writeBlocked)
        model.cancel()
    }

    @Test @MainActor func backgroundDuringReauthenticationDiscardsLateGrant() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        await repository.pauseNextReauth()
        model.rotate(password: "dummy-password")
        for _ in 0..<1000 {
            if await repository.hasPendingReauth() { break }
            await Task.yield()
        }
        #expect(await repository.hasPendingReauth())
        model.suspendForPrivacy()
        model.resumeForPrivacy()
        await repository.resumeReauth()
        await Task.yield()
        #expect(await repository.rotateCalls == 0)
        #expect(!model.lostCodes && !model.writeBlocked)
        #expect(!model.busy)
        model.cancel()
    }

    @Test @MainActor func backgroundAfterRotationDispatchDropsLateCodesWithoutReplay() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        await repository.pauseNextMutation()
        model.rotate(password: "dummy-password")
        for _ in 0..<1000 {
            if await repository.hasPendingMutation() { break }
            await Task.yield()
        }
        #expect(await repository.hasPendingMutation())
        model.suspendForPrivacy()
        #expect(model.writeBlocked && model.lostCodes && model.codes.isEmpty)
        model.resumeForPrivacy()
        await repository.resumeMutation()
        await Task.yield()
        #expect(model.codes.isEmpty)
        #expect(await repository.rotateCalls == 1)
        #expect(!model.canRotate)
        model.cancel()
    }

    @Test @MainActor func backgroundAfterUnlinkDispatchRequiresReconciliation() async {
        let authority = AccountTestAuthority()
        let repository = AccountRepositoryFake()
        let model = AccountMethodsViewModel(repository: repository, authority: authority, generation: 7)
        model.refresh()
        await settle(model)
        await repository.pauseNextMutation()
        model.unlink(password: "dummy-password")
        for _ in 0..<1000 {
            if await repository.hasPendingMutation() { break }
            await Task.yield()
        }
        #expect(await repository.hasPendingMutation())
        model.suspendForPrivacy()
        #expect(model.writeBlocked && !model.lostCodes)
        model.resumeForPrivacy()
        await repository.resumeMutation()
        await Task.yield()
        #expect(await repository.unlinkCalls == 1)
        #expect(!model.canUnlink)
        model.refresh()
        await settle(model)
        #expect(model.methods?.providers.isEmpty == true)
        #expect(!model.writeBlocked)
        model.cancel()
    }

    @MainActor private func settle(_ model: AccountMethodsViewModel) async {
        for _ in 0..<1000 {
            if !model.busy { return }
            await Task.yield()
        }
        Issue.record("Account operation did not settle")
    }
}
