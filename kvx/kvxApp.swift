//
//  kvxApp.swift
//  kvx
//
//  Created by Vinh Nguyen on 21/4/26.
//

import SwiftUI

@main
struct kvxApp: App {
    private let coordinator = SessionCoordinator(store: KeychainSessionStore(), authentication: BinblogLoginClient(session: AuthenticatedTransport.makeSession()))

    var body: some Scene {
        WindowGroup {
            SessionRootView(coordinator: coordinator)
        }
    }
}
