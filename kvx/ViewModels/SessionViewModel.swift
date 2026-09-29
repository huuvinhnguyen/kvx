import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    private(set) var state = SessionState()
    private(set) var loginError: String?
    let coordinator: SessionCoordinator

    init(coordinator: SessionCoordinator) { self.coordinator = coordinator }
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
        loginError = nil
        do { try await coordinator.login(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch SessionFailure.stale { }
        catch { loginError = error.localizedDescription }
    }
    func logout(reason: SignOutReason = .logout) async {
        loginError = nil
        _ = await coordinator.logout(reason: reason)
    }
}
