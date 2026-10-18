import Foundation

nonisolated struct AuthManagementClient: AccountAuthRepository {
    private let authority: any SessionAuthorizing
    private let generation: UInt64
    private let configuration: URLSessionConfiguration
    private static let origin = URL(string: "https://khuonvien.vn")!

    init(authority: any SessionAuthorizing, generation: UInt64,
         configuration: URLSessionConfiguration = AuthManagementClient.makeConfiguration()) {
        self.authority = authority
        self.generation = generation
        self.configuration = configuration
    }

    static func makeConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        return config
    }

    private func send(_ method: String, path: String, body: Data? = nil, lease: MutationLease? = nil,
                      beginDispatch: (@Sendable () -> Bool)? = nil) async throws -> Data {
        try Task.checkCancellation()
        let snapshot = try await authority.snapshot(expectedGeneration: generation)
        var request = URLRequest(url: Self.origin.appending(path: path), timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(snapshot.token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let prepared = request
        let receive = BoundedAuthReceive()
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    Task {
                        do {
                            let start: @Sendable () -> Void = {
                                guard beginDispatch?() != false else {
                                    continuation.resume(throwing: AccountAuthFailure.cancelled)
                                    return
                                }
                                receive.start(request: prepared, configuration: configuration, continuation: continuation)
                            }
                            if let lease {
                                try await authority.dispatchPrepared(lease, start: start)
                            } else {
                                try await authority.dispatch(snapshot.generation, start: start)
                            }
                        } catch { continuation.resume(throwing: error) }
                    }
                }
            } onCancel: { receive.cancel() }
        } catch {
            guard await authority.isCurrent(snapshot.generation) else { throw AccountAuthFailure.stale }
            if Task.isCancelled { throw AccountAuthFailure.cancelled }
            if error is AccountAuthFailure { throw error }
            throw AccountAuthFailure.network
        }
        guard await authority.isCurrent(snapshot.generation) else { throw AccountAuthFailure.stale }
        try Task.checkCancellation()
        guard response.value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "application/json" else {
            throw AccountAuthFailure.malformedResponse
        }
        let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        if response.statusCode == 401, envelope?.status == "error", envelope?.code == "authentication_required" {
            guard await authority.isCurrent(snapshot.generation) else { throw AccountAuthFailure.stale }
            guard await authority.unauthorized(snapshot.generation) else { throw AccountAuthFailure.stale }
            throw AccountAuthFailure.authenticationRequired
        }
        guard let envelope else { throw AccountAuthFailure.malformedResponse }
        if response.statusCode == 200, envelope.status == "success" { return data }
        guard envelope.status == "error", let code = envelope.code else { throw AccountAuthFailure.malformedResponse }
        throw Self.failure(status: response.statusCode, code: code)
    }

    private static func failure(status: Int, code: String) -> AccountAuthFailure {
        switch (status, code) {
        case (401, "invalid_provider_credential"): .invalidProviderCredential
        case (400, "malformed_request"): .malformedRequest
        case (403, "reauthentication_failed"): .reauthenticationFailed
        case (403, "reauthentication_required"): .reauthenticationRequired
        case (409, "last_authentication_method"): .lastAuthenticationMethod
        case (422, "unsupported_method"): .unsupportedMethod
        case (422, "unsupported_provider"): .unsupportedProvider
        case (429, "rate_limited"): .rateLimited
        case (503, "provider_unavailable"): .providerUnavailable
        case (500, "internal_error"): .serverFailure
        default: .unknown
        }
    }

    func methods() async throws -> AuthenticationMethods {
        let data = try await send("GET", path: "/api/auth/methods")
        guard let value = try? JSONDecoder().decode(MethodsSuccess.self, from: data), value.status == "success",
              value.providers.allSatisfy({ $0.provider.range(of: "^[a-z_]{1,32}$", options: .regularExpression) != nil }),
              Set(value.providers.map(\.provider)).count == value.providers.count
        else { throw AccountAuthFailure.malformedResponse }
        return AuthenticationMethods(passwordUsable: value.password.usable,
            providers: value.providers.map { ProviderMethod(provider: $0.provider, usable: $0.usable, canUnlink: $0.canUnlink) },
            codesEnrolled: value.recovery.codesEnrolled)
    }

    func reauthenticate(password: String, purpose: ReauthenticationPurpose) async throws -> ReauthenticationGrant {
        let body = try JSONEncoder().encode(PasswordRequest(purpose: purpose.rawValue, method: "password", password: password))
        let data = try await send("POST", path: "/api/auth/reauthentications", body: body)
        guard let value = try? JSONDecoder().decode(GrantSuccess.self, from: data), value.status == "success",
              !value.reauthenticationToken.isEmpty,
              let expiry = Self.date(value.expiresAt) else { throw AccountAuthFailure.malformedResponse }
        return ReauthenticationGrant(token: value.reauthenticationToken, expiresAt: expiry, purpose: purpose)
    }

    func rotateCodes(grant: ReauthenticationGrant, lease: MutationLease, beginDispatch: @escaping @Sendable () -> Bool) async throws -> [String] {
        guard let token = grant.consume(for: .rotateRecoveryCodes) else { throw AccountAuthFailure.reauthenticationRequired }
        let body = try JSONEncoder().encode(GrantRequest(reauthenticationToken: token))
        let data = try await send("POST", path: "/api/auth/recovery_codes", body: body, lease: lease, beginDispatch: beginDispatch)
        guard let value = try? JSONDecoder().decode(CodesSuccess.self, from: data),
              value.status == "success", value.code == "recovery_codes_rotated",
              value.codes.count == 10, value.codes.allSatisfy({ !$0.isEmpty }) else { throw AccountAuthFailure.malformedResponse }
        return value.codes
    }

    func unlinkGoogle(grant: ReauthenticationGrant, lease: MutationLease, beginDispatch: @escaping @Sendable () -> Bool) async throws {
        guard let token = grant.consume(for: .unlinkIdentity) else { throw AccountAuthFailure.reauthenticationRequired }
        let body = try JSONEncoder().encode(GrantRequest(reauthenticationToken: token))
        let data = try await send("DELETE", path: "/api/auth/social_identities/google", body: body, lease: lease, beginDispatch: beginDispatch)
        guard let value = try? JSONDecoder().decode(UnlinkSuccess.self, from: data),
              value.status == "success", ["unlinked", "not_linked"].contains(value.code) else {
            throw AccountAuthFailure.malformedResponse
        }
    }

    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: text) ?? {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: text)
        }()
    }

    private struct Envelope: Decodable { let status: String; let code: String? }
    private struct MethodsSuccess: Decodable {
        let status: String
        let password: Password
        let providers: [Provider]
        let recovery: Recovery
        struct Password: Decodable { let usable: Bool }
        struct Provider: Decodable {
            let provider: String; let usable: Bool; let canUnlink: Bool
            enum CodingKeys: String, CodingKey { case provider, usable, canUnlink = "can_unlink" }
        }
        struct Recovery: Decodable {
            let codesEnrolled: Bool
            enum CodingKeys: String, CodingKey { case codesEnrolled = "codes_enrolled" }
        }
    }
    private struct PasswordRequest: Encodable { let purpose: String; let method: String; let password: String }
    private struct GrantRequest: Encodable {
        let reauthenticationToken: String
        enum CodingKeys: String, CodingKey { case reauthenticationToken = "reauthentication_token" }
    }
    private struct GrantSuccess: Decodable {
        let status: String; let reauthenticationToken: String; let expiresAt: String
        enum CodingKeys: String, CodingKey { case status, reauthenticationToken = "reauthentication_token", expiresAt = "expires_at" }
    }
    private struct CodesSuccess: Decodable { let status: String; let code: String; let codes: [String] }
    private struct UnlinkSuccess: Decodable { let status: String; let code: String }
}

// URLSession is scoped to one call. Its delegate refuses redirects and stops receiving
// at the byte limit even when Content-Length is absent or incorrect.
nonisolated private final class BoundedAuthReceive: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var failure: Error?
    private var cancelled = false
    private let limit = 16 * 1024

    func start(request: URLRequest, configuration: URLSessionConfiguration,
               continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>) {
        lock.lock()
        if cancelled {
            lock.unlock()
            continuation.resume(throwing: AccountAuthFailure.cancelled)
            return
        }
        self.continuation = continuation
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock()
        self.response = response as? HTTPURLResponse
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        lock.lock()
        if chunk.count > limit - data.count {
            failure = AccountAuthFailure.malformedResponse
            lock.unlock()
            dataTask.cancel()
        } else {
            data.append(chunk)
            lock.unlock()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let result = (data, response)
        let failure = self.failure ?? error
        self.task = nil
        self.session = nil
        lock.unlock()
        session.invalidateAndCancel()
        guard let continuation else { return }
        if let failure { continuation.resume(throwing: failure) }
        else if let response = result.1 { continuation.resume(returning: (result.0, response)) }
        else { continuation.resume(throwing: AccountAuthFailure.malformedResponse) }
    }
}
