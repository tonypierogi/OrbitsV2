import SwiftUI
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    @Published var session: Session?

    private let supabase = SupabaseManager.shared.client
    private var authStateTask: Task<Void, Never>?

    init() {
        // Check for existing session
        self.session = supabase.auth.currentSession
        
        // Listen for changes to the authentication state.
        authStateTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                self.session = session
            }
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
}