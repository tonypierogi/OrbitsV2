import Foundation
import OrbitsKit

@MainActor
class ContactDetailViewModel: ObservableObject {
    @Published var person: Person
    @Published var notes: [Note] = []
    @Published var tags: [Tag] = []
    @Published var availableOrbits: [Orbit] = []
    
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
    
    var currentOrbit: Orbit? {
        person.orbit
    }
    
    var lastContactText: String? {
        guard let lastMessageDate = person.lastMessageAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day ?? 0
        
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else {
            return "\(days) days ago"
        }
    }
    
    var isOverdue: Bool {
        guard let orbit = person.orbit,
              let lastMessageDate = person.lastMessageAt else { return false }
        
        let days = Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day ?? 0
        return days > orbit.intervalDays
    }
    
    var orbitStatusText: String? {
        guard let orbit = person.orbit,
              let lastMessageDate = person.lastMessageAt else { return nil }
        
        let days = Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day ?? 0
        let daysOverdue = days - orbit.intervalDays
        
        if daysOverdue > 0 {
            return "\(daysOverdue) days overdue"
        } else if days >= orbit.intervalDays - orbit.slackDays {
            let daysUntilDue = orbit.intervalDays - days
            return "Due in \(daysUntilDue) days"
        } else {
            return "On track"
        }
    }
    
    struct ContactMethod: Hashable {
        let icon: String
        let value: String
        let action: () -> Void
        
        static func == (lhs: ContactMethod, rhs: ContactMethod) -> Bool {
            lhs.value == rhs.value && lhs.icon == rhs.icon
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(icon)
            hasher.combine(value)
        }
    }
    
    var contactMethods: [ContactMethod] {
        var methods: [ContactMethod] = []
        
        let identifier = person.contactIdentifier
        
        if identifier.contains("@") {
            methods.append(ContactMethod(
                icon: "envelope",
                value: identifier,
                action: { }
            ))
        } else if identifier.contains("+") || CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: identifier)) {
            methods.append(ContactMethod(
                icon: "phone",
                value: identifier,
                action: { }
            ))
        }
        
        return methods
    }
    
    func loadData() async {
        do {
            async let notesTask = supabaseService.fetchNotes(for: person.id)
            async let tagsTask = supabaseService.fetchTags()
            async let orbitsTask = supabaseService.fetchOrbits()
            
            let (fetchedNotes, fetchedTags, fetchedOrbits) = try await (notesTask, tagsTask, orbitsTask)
            
            self.notes = fetchedNotes
            self.tags = fetchedTags
            self.availableOrbits = fetchedOrbits
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    func assignToOrbit(_ orbit: Orbit) async {
        do {
            try await supabaseService.assignPersonToOrbit(
                personId: person.id.uuidString,
                orbitId: orbit.id.uuidString
            )
            
            person = Person(
                id: person.id,
                userId: person.userId,
                contactIdentifier: person.contactIdentifier,
                displayName: person.displayName,
                photoHash: person.photoHash,
                photoAvailable: person.photoAvailable,
                orbitId: orbit.id,
                unreadCount: person.unreadCount,
                lastMessageAt: person.lastMessageAt,
                createdAt: person.createdAt,
                updatedAt: Date(),
                orbit: orbit
            )
        } catch {
            print("Error assigning orbit: \(error)")
        }
    }
    
    func addNote(_ content: String) async {
        // This would need a createNote method in SupabaseService
        // For now, this is a placeholder
    }
    
    func addTag() {
        // This would show a tag picker/creator
        // For now, this is a placeholder
    }
    
    func removeTag(_ tag: Tag) async {
        // This would remove the tag association
        // For now, this is a placeholder
    }
    
    func markContacted() {
        // This would update the last contact date
        // For now, this is a placeholder
    }
}