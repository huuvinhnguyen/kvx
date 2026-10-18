import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    private(set) var state = SessionState()
    private(set) var loginError: String?
    private(set) var isSessionTransitioning = false
    let coordinator: SessionCoordinator
    private let googleSignIn: GoogleSignInUseCase?

    init(coordinator: SessionCoordinator, googleSignIn: GoogleSignInUseCase? = nil) {
        self.coordinator = coordinator
        self.googleSignIn = googleSignIn
    }
    func observeAndRestore() async {
        let changes = await coordinator.changes()
        await coordinator.restore()
        for await state in changes {
            guard !Task.isCancelled else { return }
            self.state = state
        }
    }
    func retryRestore() async { await coordinator.restore() }
    func login(username: String, password: String) async {
        guard !isSessionTransitioning else { return }
        loginError = nil
        do { try await coordinator.login(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch SessionFailure.stale { }
        catch { loginError = error.localizedDescription }
    }
    func loginWithGoogle() async {
        guard !isSessionTransitioning else { return }
        loginError = nil
        guard let googleSignIn else {
            loginError = AuthenticationAttemptFailure.providerConfigurationFailure.localizedDescription
            return
        }
        do { try await coordinator.authenticate { try await googleSignIn.execute() } }
        catch SessionFailure.stale { }
        catch AuthenticationAttemptFailure.userCancelled { }
        catch { loginError = error.localizedDescription }
    }
    func logout(reason: SignOutReason = .logout) async {
        guard !isSessionTransitioning else { return }
        isSessionTransitioning = true
        defer { isSessionTransitioning = false }
        loginError = nil
        let completed = await coordinator.logout(reason: reason)
        if completed { await googleSignIn?.signOut() }
    }
}
