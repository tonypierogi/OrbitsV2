import SwiftUI
import Supabase

@MainActor
public final class AuthManager: ObservableObject {
    @Published public var session: Session?

    private let supabase = SupabaseManager.shared.client
    private var authStateTask: Task<Void, Never>?

    public init() {
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