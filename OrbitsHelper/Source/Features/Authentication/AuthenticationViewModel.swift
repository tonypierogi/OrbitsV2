import Foundation
import OrbitsKit
import Supabase

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var authError: Error?
    
    private let supabase = SupabaseManager.shared.client

    func signUp() async {
        isLoading = true
        authError = nil
        do {
            _ = try await supabase.auth.signUp(email: email, password: password)
            // Note: Supabase sends a confirmation email by default.
            // The user's session won't be active until they confirm.
        } catch {
            authError = error
        }
        isLoading = false
    }

    func signIn() async {
        isLoading = true
        authError = nil
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
        } catch {
            authError = error
        }
        isLoading = false
    }
}