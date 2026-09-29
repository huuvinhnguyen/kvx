import Foundation

@MainActor
final class GoogleSignInUseCase {
    private let credentials: any GoogleCredentialProviding
    private let sessions: any SocialSessionExchanging

    init(credentials: any GoogleCredentialProviding, sessions: any SocialSessionExchanging) {
        self.credentials = credentials
        self.sessions = sessions
    }

    func execute() async throws -> String {
        let credential = try await credentials.credential()
        return try await sessions.exchange(provider: "google", credential: credential)
    }

    func signOut() async {
        try? await credentials.signOut()
    }
}
