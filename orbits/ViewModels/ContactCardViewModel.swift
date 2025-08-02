import Foundation
import OrbitsKit

@MainActor
class ContactCardViewModel: ObservableObject {
    let person: Person
    private let supabaseService: SupabaseService
    
    init(person: Person, supabaseService: SupabaseService) {
        self.person = person
        self.supabaseService = supabaseService
    }
    
    var displayName: String {
        person.displayName ?? person.contactIdentifier
    }
    
    var initials: String {
        guard let name = person.displayName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }
    
    var daysSinceLastContact: Int? {
        guard let lastMessageDate = person.lastMessageDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day
    }
    
    var isOverdue: Bool {
        guard let orbit = person.orbit,
              let days = daysSinceLastContact else { return false }
        return days > orbit.intervalDays
    }
    
    var daysOverdue: Int? {
        guard let orbit = person.orbit,
              let days = daysSinceLastContact else { return nil }
        let overdue = days - orbit.intervalDays
        return overdue > 0 ? overdue : nil
    }
    
    var daysUntilDue: Int? {
        guard let orbit = person.orbit,
              let days = daysSinceLastContact else { return nil }
        let remaining = orbit.intervalDays - days
        return remaining > 0 ? remaining : nil
    }
    
    var lastContactText: String {
        guard let days = daysSinceLastContact else { return "Never contacted" }
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else {
            return "\(days) days ago"
        }
    }
    
    var statusText: String {
        guard let orbit = person.orbit else { return "No orbit assigned" }
        
        if let daysOverdue = daysOverdue {
            return "\(daysOverdue) days overdue"
        } else if let daysUntilDue = daysUntilDue {
            if daysUntilDue <= orbit.slackDays {
                return "Due in \(daysUntilDue) days"
            } else {
                return "On track"
            }
        }
        return ""
    }
    
    func markContacted() async throws {
        // This would update the last contact date
        // For now, this is a placeholder as we need to implement
        // a way to track manual contact updates
    }
}