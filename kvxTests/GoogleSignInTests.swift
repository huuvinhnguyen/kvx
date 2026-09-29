import Foundation
import Testing
@testable import kvx

private final class SocialSessionHTTPStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        if path == "/network" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let components = path.split(separator: "/")
        let status = Int(components.first ?? "") ?? 200
        let code = components.dropFirst().first.map(String.init)
        let body: String
        if status == 200 {
            body = path.contains("malformed")
                ? #"{"status":"success","token":""}"#
                : #"{"status":"success","token":"binblog-session","user":{"id":1,"username":"fixture","email":"fixture@example.com"}}"#
        } else {
            body = #"{"status":"error","code":"\#(code ?? "unknown")"}"#
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private actor GoogleMemoryStore: SessionStore {
    var value: StoredSession?
    var writes: [StoredSession] = []
    init(_ value: StoredSession? = nil) { self.value = value }
    func read() -> StoredSession? { value }
    func write(_ value: StoredSession) { writes.append(value); self.value = value }
    func delete() { value = nil }
}

private struct GooglePasswordFake: PasswordAuthenticating {
    func login(username: String, password: String) async throws -> String { "password-session" }
}

private actor CountingGooglePasswordFake: PasswordAuthenticating {
    private(set) var calls = 0

    func login(username: String, password: String) async throws -> String {
        calls += 1
        return "password-session"
    }
}

@MainActor
private final class GoogleCredentialFake: GoogleCredentialProviding, @unchecked Sendable {
    var token = "google-id-token"
    var failure: AuthenticationAttemptFailure?
    var signOutFailure = false
    var credentialCalls = 0
    var signOutCalls = 0
    var continuation: CheckedContinuation<String, Error>?
    var pauseSignOut = false
    var signOutContinuation: CheckedContinuation<Void, Never>?

    func credential() async throws -> String {
        credentialCalls += 1
        if let failure { throw failure }
        if continuation != nil { Issue.record("Only one pending credential is supported") }
        return token
    }

    func pausedCredential() async throws -> String {
        credentialCalls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func finishCredential() {
        continuation?.resume(returning: token)
        continuation = nil
    }

    func signOut() async throws {
        signOutCalls += 1
        if pauseSignOut {
            await withCheckedContinuation { signOutContinuation = $0 }
        }
        if signOutFailure { throw AuthenticationAttemptFailure.providerFailure }
    }

    func finishSignOut() {
        signOutContinuation?.resume()
        signOutContinuation = nil
    }
}

private actor SocialSessionFake: SocialSessionExchanging {
    var receivedProvider: String?
    var receivedCredential: String?
    var token = "binblog-session"
    func exchange(provider: String, credential: String) -> String {
        receivedProvider = provider
        receivedCredential = credential
        return token
    }
}

@MainActor
struct GoogleSocialSessionTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SocialSessionHTTPStub.self]
        return URLSession(configuration: configuration)
    }

    private func client(_ path: String) -> SocialSessionClient {
        SocialSessionClient(endpoint: URL(string: "https://social.test/\(path)")!, session: session())
    }

    @Test func requestContainsOnlyProviderAndCredentialAndReturnsBinblogJWT() async throws {
        let recording = RequestRecordingProtocol.session { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
            #expect(payload == ["provider": "google", "credential": "google-id-token"])
            return (200, #"{"status":"success","token":"binblog-session","user":{}}"#)
        }
        let subject = SocialSessionClient(
            endpoint: URL(string: "https://social.test/api/auth/social_sessions")!,
            session: recording
        )
        #expect(try await subject.exchange(provider: "google", credential: "google-id-token") == "binblog-session")
    }

    @Test(arguments: [
        (400, "malformed_request", AuthenticationAttemptFailure.malformedResponse),
        (401, "invalid_provider_credential", .invalidProviderCredential),
        (409, "link_required", .linkRequired),
        (422, "unsupported_provider", .providerFailure),
        (422, "email_verification_required", .emailVerificationRequired),
        (503, "provider_unavailable", .providerUnavailable),
        (503, "username_unavailable", .usernameUnavailable),
        (500, "internal_error", .serverFailure),
    ])
    func mapsDocumentedBackendErrors(status: Int, code: String, expected: AuthenticationAttemptFailure) async {
        do {
            _ = try await client("\(status)/\(code)").exchange(provider: "google", credential: "fixture")
            Issue.record("Expected mapped backend failure")
        } catch let failure as AuthenticationAttemptFailure {
            #expect(failure == expected)
        } catch { Issue.record("Unexpected failure type") }
    }

    @Test func networkAndMalformedSuccessNeverReturnCandidate() async {
        for (subject, expected) in [
            (client("network"), AuthenticationAttemptFailure.networkFailure),
            (client("200/malformed"), .malformedResponse),
        ] {
            do {
                _ = try await subject.exchange(provider: "google", credential: "fixture")
                Issue.record("Expected failure")
            } catch let failure as AuthenticationAttemptFailure {
                #expect(failure == expected)
            } catch { Issue.record("Unexpected failure type") }
        }
    }

    @Test func coordinatorPersistsOnlyBinblogCandidateAndPreservesCancellation() async throws {
        let store = GoogleMemoryStore()
        let coordinator = SessionCoordinator(store: store, authentication: GooglePasswordFake())
        let credentials = GoogleCredentialFake()
        let sessions = SocialSessionFake()
        let useCase = GoogleSignInUseCase(credentials: credentials, sessions: sessions)
        await coordinator.restore()
        try await coordinator.authenticate { try await useCase.execute() }
        #expect(await sessions.receivedProvider == "google")
        #expect(await sessions.receivedCredential == "google-id-token")
        #expect(await store.writes == [.active("binblog-session")])
        #expect(try await coordinator.snapshot().token == "binblog-session")

        #expect(await coordinator.logout())
        credentials.failure = .userCancelled
        do {
            try await coordinator.authenticate { try await useCase.execute() }
            Issue.record("Expected cancellation")
        } catch AuthenticationAttemptFailure.userCancelled {}
        #expect(await coordinator.state.phase == .signedOut)
        #expect(await store.writes.last == .signedOut)
    }

    @Test func missingCredentialNeverCallsRailsOrWritesSession() async {
        let store = GoogleMemoryStore()
        let coordinator = SessionCoordinator(store: store, authentication: GooglePasswordFake())
        let credentials = GoogleCredentialFake()
        credentials.failure = .missingCredential
        let sessions = SocialSessionFake()
        let useCase = GoogleSignInUseCase(credentials: credentials, sessions: sessions)
        await coordinator.restore()

        do {
            try await coordinator.authenticate { try await useCase.execute() }
            Issue.record("Expected missing credential")
        } catch AuthenticationAttemptFailure.missingCredential {} catch {
            Issue.record("Unexpected missing-credential failure")
        }
        #expect(await sessions.receivedCredential == nil)
        #expect(await store.writes.isEmpty)
        #expect(await coordinator.state.phase == .signedOut)
    }

    @Test func duplicateGoogleSubmitIsRejectedWhileFirstAttemptIsActive() async {
        let coordinator = SessionCoordinator(store: GoogleMemoryStore(), authentication: GooglePasswordFake())
        let credentials = GoogleCredentialFake()
        await coordinator.restore()
        let pending = Task {
            try await coordinator.authenticate { try await credentials.pausedCredential() }
        }
        while credentials.continuation == nil { await Task.yield() }

        do {
            try await coordinator.authenticate { try await credentials.credential() }
            Issue.record("Expected duplicate submit rejection")
        } catch SessionFailure.signedOut {} catch { Issue.record("Unexpected duplicate-submit failure") }
        #expect(credentials.credentialCalls == 1)
        #expect(await coordinator.logout())
        credentials.finishCredential()
        _ = try? await pending.value
    }

    @Test func logoutFencesLateGoogleCompletion() async {
        let store = GoogleMemoryStore()
        let coordinator = SessionCoordinator(store: store, authentication: GooglePasswordFake())
        let credentials = GoogleCredentialFake()
        let pending = Task {
            try await coordinator.authenticate { try await credentials.pausedCredential() }
        }
        while credentials.continuation == nil { await Task.yield() }
        #expect(await coordinator.logout())
        credentials.finishCredential()
        do {
            try await pending.value
            Issue.record("Expected stale provider completion")
        } catch SessionFailure.stale {} catch { Issue.record("Unexpected stale failure") }
        #expect(await store.writes == [.signedOut])
    }

    @Test func accountSwitchFencesLateGoogleCompletion() async throws {
        let store = GoogleMemoryStore()
        let coordinator = SessionCoordinator(store: store, authentication: GooglePasswordFake())
        let credentials = GoogleCredentialFake()
        let pending = Task {
            try await coordinator.authenticate { try await credentials.pausedCredential() }
        }
        while credentials.continuation == nil { await Task.yield() }

        try await coordinator.switchAccount(username: "fixture", password: "fixture")
        credentials.finishCredential()

        do {
            try await pending.value
            Issue.record("Expected stale provider completion")
        } catch SessionFailure.stale {} catch { Issue.record("Unexpected stale failure") }
        #expect(try await coordinator.snapshot().token == "password-session")
        #expect(await store.writes == [.signedOut, .active("password-session")])
    }

    @Test func delayedProviderCleanupKeepsBothLoginPathsGatedAfterDurableLogout() async {
        let store = GoogleMemoryStore(.active("session"))
        let password = CountingGooglePasswordFake()
        let coordinator = SessionCoordinator(store: store, authentication: password)
        let credentials = GoogleCredentialFake()
        credentials.pauseSignOut = true
        let useCase = GoogleSignInUseCase(credentials: credentials, sessions: SocialSessionFake())
        let model = SessionViewModel(coordinator: coordinator, googleSignIn: useCase)
        await coordinator.restore()

        let logout = Task { await model.logout(reason: .switching) }
        while credentials.signOutContinuation == nil { await Task.yield() }

        #expect(await coordinator.state.phase == .signedOut)
        #expect(await store.value == .signedOut)
        #expect(model.isSessionTransitioning)
        await model.login(username: "other", password: "password")
        await model.loginWithGoogle()
        #expect(await password.calls == 0)
        #expect(credentials.credentialCalls == 0)

        credentials.finishSignOut()
        await logout.value
        #expect(!model.isSessionTransitioning)

        await model.login(username: "other", password: "password")
        #expect(await password.calls == 1)
        #expect(await coordinator.state.phase == .authenticated)
        #expect(credentials.signOutCalls == 1)
    }

    @Test func delayedProviderCleanupFailureLeavesSignedOutAndReenablesLogin() async {
        let store = GoogleMemoryStore(.active("session"))
        let password = CountingGooglePasswordFake()
        let coordinator = SessionCoordinator(store: store, authentication: password)
        let credentials = GoogleCredentialFake()
        credentials.pauseSignOut = true
        credentials.signOutFailure = true
        let useCase = GoogleSignInUseCase(credentials: credentials, sessions: SocialSessionFake())
        let model = SessionViewModel(coordinator: coordinator, googleSignIn: useCase)
        await coordinator.restore()

        let logout = Task { await model.logout() }
        while credentials.signOutContinuation == nil { await Task.yield() }
        #expect(await coordinator.state.phase == .signedOut)
        #expect(await store.value == .signedOut)
        #expect(model.isSessionTransitioning)

        credentials.finishSignOut()
        await logout.value
        #expect(!model.isSessionTransitioning)
        #expect(await coordinator.state.phase == .signedOut)
        #expect(await store.value == .signedOut)

        await model.login(username: "other", password: "password")
        #expect(await password.calls == 1)
        #expect(await coordinator.state.phase == .authenticated)
    }
}

private final class RequestRecordingProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler?(request) ?? (500, "{}")
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}

    static func session(handler: @escaping (URLRequest) throws -> (Int, String)) -> URLSession {
        Self.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Self.self]
        return URLSession(configuration: configuration)
    }
}
