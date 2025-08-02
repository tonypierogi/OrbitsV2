import Foundation
import OrbitsKit

@MainActor
class UnreadInboxViewModel: ObservableObject {
    @Published var unreadContacts: [Person] = []
    @Published var isLoading = false
    
    let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    
    func loadUnreadContacts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let allPersons = try await supabaseService.fetchPersons()
            // Filter to only show contacts with unread messages
            self.unreadContacts = allPersons
                .filter { person in
                    // Must have unread messages
                    guard person.unreadCount > 0 else { return false }
                    
                    // Filter out contacts without a real saved name
                    if let displayName = person.displayName {
                        // Check if displayName is just a phone number or short code
                        let digitsOnly = displayName.filter { $0.isNumber }
                        let nonDigits = displayName.filter { !$0.isNumber && $0 != "+" && $0 != "-" && $0 != " " && $0 != "(" && $0 != ")" }
                        
                        // If display name has no letters (only digits/phone formatting), skip it
                        if nonDigits.isEmpty {
                            return false
                        }
                        
                        // Also skip short codes (less than 8 digits)
                        if digitsOnly.count < 8 && nonDigits.isEmpty {
                            return false
                        }
                    } else {
                        // No display name at all
                        return false
                    }
                    
                    return true
                }
                .sorted { $0.unreadCount > $1.unreadCount }
        } catch {
            print("Error loading unread contacts: \(error)")
        }
    }
}