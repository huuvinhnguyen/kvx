//
//  kvxApp.swift
//  kvx
//
//  Created by Vinh Nguyen on 21/4/26.
//

import SwiftUI
import GoogleSignIn

@main
struct kvxApp: App {
    private let coordinator = SessionCoordinator(store: KeychainSessionStore(), authentication: BinblogLoginClient(session: AuthenticatedTransport.makeSession()))
    private let googleSignIn = GoogleSignInUseCase(
        credentials: GoogleSignInAdapter(),
        sessions: SocialSessionClient()
    )

    var body: some Scene {
        WindowGroup {
            SessionRootView(coordinator: coordinator, googleSignIn: googleSignIn)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
