import Foundation
import SwiftUI
import OrbitsKit

@MainActor
class NewContactsViewModel: ObservableObject {
    @Published var recentContacts: [Person] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService: SupabaseService
    
    init() {
        self.supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    }
    
    func loadRecentContacts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            recentContacts = try await supabaseService.fetchRecentContacts()
        } catch {
            errorMessage = "Failed to load recent contacts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}