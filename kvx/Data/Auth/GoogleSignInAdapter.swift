import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class GoogleSignInAdapter: GoogleCredentialProviding, @unchecked Sendable {
    func credential() async throws -> String {
        guard isConfigured else {
            throw AuthenticationAttemptFailure.providerConfigurationFailure
        }
        guard let presentingViewController = UIApplication.shared.googleSignInPresentingViewController else {
            throw AuthenticationAttemptFailure.providerFailure
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = try await result.user.refreshTokensIfNeeded()
            guard let token = user.idToken?.tokenString,
                  !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw AuthenticationAttemptFailure.missingCredential }
            return token
        } catch let failure as AuthenticationAttemptFailure {
            throw failure
        } catch {
            let providerError = error as NSError
            if providerError.domain == kGIDSignInErrorDomain,
               providerError.code == -5 { // kGIDSignInErrorCodeCanceled
                throw AuthenticationAttemptFailure.userCancelled
            }
            throw AuthenticationAttemptFailure.providerFailure
        }
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
    }

    private var isConfigured: Bool {
        guard let clientID = configuredValue(for: "GIDClientID"),
              let serverClientID = configuredValue(for: "GIDServerClientID"),
              let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        else { return false }
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return schemes.contains(clientID.reversedGoogleClientID) && !serverClientID.isEmpty
    }

    private func configuredValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }
}

private extension UIApplication {
    var googleSignInPresentingViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

private extension String {
    var reversedGoogleClientID: String {
        split(separator: ".").reversed().joined(separator: ".")
    }
}
