import SwiftUI
import OrbitsKit

@main
struct OrbitsHelperApp: App {
    // Use the shared AuthManager from our OrbitsKit package
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            // Switch between login and main view based on auth state
            if authManager.session != nil {
                MainView()
            } else {
                AuthenticationView()
            }
        }
    }
}