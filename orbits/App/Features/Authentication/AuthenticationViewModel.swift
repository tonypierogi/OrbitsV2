import SwiftUI
import Supabase
import OrbitsKit

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var authError: Error?
    
    private let supabase = SupabaseManager.shared.client
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)

    func signUp() async {
        isLoading = true
        authError = nil
        do {
            let authResponse = try await supabase.auth.signUp(email: email, password: password)
            // Note: Supabase sends a confirmation email by default.
            // The user's session won't be active until they confirm.
            
            // If we have a user ID (some Supabase configs allow immediate login), create default orbits
            let userId = authResponse.user.id.uuidString
            // Check if user already has orbits (in case of re-signup)
            let hasOrbits = try await supabaseService.hasDefaultOrbits(for: userId)
            if !hasOrbits {
                try await supabaseService.createDefaultOrbits(for: userId)
            }
        } catch {
            authError = error
        }
        isLoading = false
    }

    func signIn() async {
        isLoading = true
        authError = nil
        do {
            let authResponse = try await supabase.auth.signIn(email: email, password: password)
            
            // After successful sign in, ensure user has default orbits
            let userId = authResponse.user.id.uuidString
            let hasOrbits = try await supabaseService.hasDefaultOrbits(for: userId)
            if !hasOrbits {
                try await supabaseService.createDefaultOrbits(for: userId)
            }
        } catch {
            authError = error
        }
        isLoading = false
    }
}