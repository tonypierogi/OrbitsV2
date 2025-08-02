import Foundation
import OrbitsKit

@MainActor
class OrbitsViewModel: ObservableObject {
    @Published var orbits: [Orbit] = []
    @Published var peopleNeedingAttention: [Person] = []
    @Published var isLoading = false
    
    let supabaseService: SupabaseService
    
    // Track snoozed people during this session
    private var snoozedPeople: Set<UUID> = []
    private var snoozeExpirations: [UUID: Date] = [:]
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load orbits and people in parallel
            async let orbitsTask = supabaseService.fetchOrbits()
            async let peopleTask = supabaseService.fetchPersons()
            
            let (fetchedOrbits, fetchedPeople) = try await (orbitsTask, peopleTask)
            
            self.orbits = fetchedOrbits.sorted { $0.position < $1.position }
            
            // Find people who need attention (overdue based on their orbit)
            var needingAttention: [Person] = []
            
            for person in fetchedPeople {
                guard let orbitId = person.orbitId,
                      let orbit = fetchedOrbits.first(where: { $0.id == orbitId }),
                      let lastMessageDate = person.lastMessageAt else { continue }
                
                // Filter out contacts without a real saved name
                if let displayName = person.displayName {
                    // Check if displayName is just a phone number or short code
                    let digitsOnly = displayName.filter { $0.isNumber }
                    let nonDigits = displayName.filter { !$0.isNumber && $0 != "+" && $0 != "-" && $0 != " " && $0 != "(" && $0 != ")" }
                    
                    // If display name has no letters (only digits/phone formatting), skip it
                    if nonDigits.isEmpty {
                        continue
                    }
                    
                    // Also skip short codes (less than 8 digits)
                    if digitsOnly.count < 8 && nonDigits.isEmpty {
                        continue
                    }
                } else {
                    // No display name at all
                    continue
                }
                
                let daysSinceLastMessage = Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day ?? 0
                
                // Check if overdue (past interval days + slack days)
                if daysSinceLastMessage > orbit.intervalDays {
                    // Check if person is snoozed
                    if let expirationDate = snoozeExpirations[person.id] {
                        if Date() < expirationDate {
                            // Still snoozed, skip
                            continue
                        } else {
                            // Snooze expired, remove from tracking
                            snoozedPeople.remove(person.id)
                            snoozeExpirations.removeValue(forKey: person.id)
                        }
                    }
                    
                    needingAttention.append(person)
                }
            }
            
            // Sort by most overdue first
            self.peopleNeedingAttention = needingAttention.sorted { person1, person2 in
                let days1 = daysSinceLastContact(for: person1) ?? 0
                let days2 = daysSinceLastContact(for: person2) ?? 0
                return days1 > days2
            }
        } catch {
            print("Error loading orbits data: \(error)")
        }
    }
    
    private func daysSinceLastContact(for person: Person) -> Int? {
        guard let lastMessageDate = person.lastMessageAt else { return nil }
        return Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day
    }
    
    func snooze(person: Person, days: Int) async {
        // Add to snoozed list with expiration date
        let expirationDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        await MainActor.run {
            snoozedPeople.insert(person.id)
            snoozeExpirations[person.id] = expirationDate
            peopleNeedingAttention.removeAll { $0.id == person.id }
        }
        
        print("Snoozed \(person.displayName ?? person.contactIdentifier) until \(expirationDate)")
    }
    
    func removeOrbit(from person: Person) async {
        do {
            print("Removing orbit from person: \(person.displayName ?? person.contactIdentifier)")
            
            // Remove orbit assignment
            try await supabaseService.removeOrbitFromPerson(
                personId: person.id.uuidString
            )
            
            print("Successfully removed orbit from database")
            
            // Remove from local list instead of full reload
            await MainActor.run {
                peopleNeedingAttention.removeAll { $0.id == person.id }
            }
        } catch {
            print("Error removing orbit: \(error)")
            print("Person ID: \(person.id.uuidString)")
        }
    }
}