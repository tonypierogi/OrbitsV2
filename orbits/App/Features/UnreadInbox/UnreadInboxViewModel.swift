import Foundation
import OrbitsKit

@MainActor
class UnreadInboxViewModel: ObservableObject {
    @Published var unreadContacts: [Person] = []
    @Published var isLoading = false
    
    // Sorting and filtering
    @Published var sortOption: SortOption = .newest
    @Published var selectedOrbitIds: Set<UUID> = []
    @Published var selectedTagIds: Set<UUID> = []
    @Published var selectedCategoryIds: Set<UUID> = []
    @Published var availableOrbits: [Orbit] = []
    @Published var availableTags: [Tag] = []
    @Published var availableCategories: [TagCategory] = []
    
    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case name = "Name"
        
        var icon: String {
            switch self {
            case .newest: return "arrow.down"
            case .oldest: return "arrow.up"
            case .name: return "textformat"
            }
        }
    }
    
    private var allUnreadContacts: [Person] = []
    @Published var personTags: [UUID: [Tag]] = [:]
    
    let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    
    func loadUnreadContacts() async {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load all data in parallel
            async let personsTask = supabaseService.fetchPersons()
            async let orbitsTask = supabaseService.fetchOrbits()
            async let tagsTask = supabaseService.fetchTags()
            async let categoriesTask = supabaseService.fetchTagCategories()
            
            let (allPersons, orbits, tags, categories) = try await (personsTask, orbitsTask, tagsTask, categoriesTask)
            
            // Update available filters
            self.availableOrbits = orbits.sorted { $0.position < $1.position }
            self.availableTags = tags.sorted { $0.label < $1.label }
            self.availableCategories = categories.sorted { $0.name < $1.name }
            
            // Load person-tag relationships
            var tagMap: [UUID: [Tag]] = [:]
            for person in allPersons {
                if person.unreadCount > 0 || person.needsResponse {
                    let personTags = try await supabaseService.fetchTagsForPerson(person.id)
                    tagMap[person.id] = personTags
                }
            }
            self.personTags = tagMap
            
            // Filter to only show contacts with unread messages or needs response
            self.allUnreadContacts = allPersons
                .filter { person in
                    // Must have unread messages or needs response
                    guard person.unreadCount > 0 || person.needsResponse else { return false }
                    
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
            
            // Apply filters and sorting
            applyFiltersAndSorting()
        } catch {
            print("Error loading unread contacts: \(error)")
        }
    }
    
    func applyFiltersAndSorting() {
        var filtered = allUnreadContacts
        
        // Apply orbit filter
        if !selectedOrbitIds.isEmpty {
            filtered = filtered.filter { person in
                if let orbitId = person.orbitId {
                    return selectedOrbitIds.contains(orbitId)
                }
                return false
            }
        }
        
        // Apply tag filter
        if !selectedTagIds.isEmpty {
            filtered = filtered.filter { person in
                let tags = personTags[person.id] ?? []
                return tags.contains { selectedTagIds.contains($0.id) }
            }
        }
        
        // Apply category filter
        if !selectedCategoryIds.isEmpty {
            filtered = filtered.filter { person in
                let tags = personTags[person.id] ?? []
                return tags.contains { tag in
                    if let categoryId = tag.categoryId {
                        return selectedCategoryIds.contains(categoryId)
                    }
                    return false
                }
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .newest:
            filtered.sort { person1, person2 in
                if let date1 = person1.lastMessageAt, let date2 = person2.lastMessageAt {
                    return date1 > date2
                } else if person1.lastMessageAt != nil {
                    return true
                } else {
                    return false
                }
            }
        case .oldest:
            filtered.sort { person1, person2 in
                if let date1 = person1.lastMessageAt, let date2 = person2.lastMessageAt {
                    return date1 < date2
                } else if person2.lastMessageAt != nil {
                    return true
                } else {
                    return false
                }
            }
        case .name:
            filtered.sort { person1, person2 in
                let name1 = person1.displayName ?? person1.contactIdentifier
                let name2 = person2.displayName ?? person2.contactIdentifier
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
        
        self.unreadContacts = filtered
    }
    
    func setSortOption(_ option: SortOption) {
        sortOption = option
        applyFiltersAndSorting()
    }
    
    func toggleOrbitFilter(_ orbitId: UUID) {
        if selectedOrbitIds.contains(orbitId) {
            selectedOrbitIds.remove(orbitId)
        } else {
            selectedOrbitIds.insert(orbitId)
        }
        applyFiltersAndSorting()
    }
    
    func toggleTagFilter(_ tagId: UUID) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
        applyFiltersAndSorting()
    }
    
    func toggleCategoryFilter(_ categoryId: UUID) {
        if selectedCategoryIds.contains(categoryId) {
            selectedCategoryIds.remove(categoryId)
        } else {
            selectedCategoryIds.insert(categoryId)
        }
        applyFiltersAndSorting()
    }
    
    func clearAllFilters() {
        selectedOrbitIds.removeAll()
        selectedTagIds.removeAll()
        selectedCategoryIds.removeAll()
        applyFiltersAndSorting()
    }
}