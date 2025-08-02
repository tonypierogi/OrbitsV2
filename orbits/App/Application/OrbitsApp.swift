import SwiftUI
import OrbitsKit

@main
struct OrbitsApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            // If there is an active session, show the main app.
            // Otherwise, show the authentication screen.
            if authManager.session != nil {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
    }
}
