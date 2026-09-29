import Foundation

nonisolated struct SocialSessionClient: SocialSessionExchanging {
    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "https://khuonvien.vn/api/auth/social_sessions")!,
        session: URLSession = SocialSessionClient.makeSession()
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    func exchange(provider: String, credential: String) async throws -> String {
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(Request(provider: provider, credential: credential))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AuthenticationAttemptFailure.networkFailure
        }

        guard let response = response as? HTTPURLResponse else {
            throw AuthenticationAttemptFailure.malformedResponse
        }
        if response.statusCode == 200 {
            guard let result = try? JSONDecoder().decode(Success.self, from: data),
                  result.status == "success",
                  !result.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw AuthenticationAttemptFailure.malformedResponse }
            return result.token
        }

        let code = (try? JSONDecoder().decode(Failure.self, from: data))?.code
        throw map(status: response.statusCode, code: code)
    }

    private func map(status: Int, code: String?) -> AuthenticationAttemptFailure {
        switch (status, code) {
        case (400, "malformed_request"):
            return .malformedResponse
        case (401, "invalid_provider_credential"):
            return .invalidProviderCredential
        case (409, "link_required"):
            return .linkRequired
        case (422, "unsupported_provider"):
            return .providerFailure
        case (422, "email_verification_required"):
            return .emailVerificationRequired
        case (503, "provider_unavailable"):
            return .providerUnavailable
        case (503, "username_unavailable"):
            return .usernameUnavailable
        case (500, "internal_error"):
            return .serverFailure
        default:
            return .malformedResponse
        }
    }

    private struct Request: Encodable {
        let provider: String
        let credential: String
    }

    private struct Success: Decodable {
        let status: String
        let token: String
    }

    private struct Failure: Decodable {
        let code: String
    }
}
