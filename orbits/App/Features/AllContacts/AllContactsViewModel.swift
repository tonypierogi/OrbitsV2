import Foundation
import SwiftUI
import OrbitsKit

enum SortOrder {
    case ascending
    case descending
}

@MainActor
class AllContactsViewModel: ObservableObject {
    @Published var allContacts: [Person] = []
    @Published var allTags: [Tag] = []
    @Published var personTags: [PersonTag] = []
    @Published var selectedTagIds: Set<UUID> = []
    @Published var sortOrder: SortOrder = .ascending
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService: SupabaseService
    
    init() {
        self.supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let contactsTask = supabaseService.fetchPersons()
            async let tagsTask = supabaseService.fetchTags()
            async let personTagsTask = supabaseService.fetchAllPersonTags()
            
            let (contacts, tags, personTagsData) = try await (contactsTask, tagsTask, personTagsTask)
            
            allContacts = contacts
            allTags = tags
            personTags = personTagsData
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    var filteredAndSortedContacts: [Person] {
        var contacts = allContacts
        
        // Filter by tags if any are selected
        if !selectedTagIds.isEmpty {
            contacts = contacts.filter { person in
                let personTagIds = personTags
                    .filter { $0.personId == person.id }
                    .map { $0.tagId }
                
                // OR logic - person has at least one of the selected tags
                return !Set(personTagIds).isDisjoint(with: selectedTagIds)
            }
        }
        
        // Sort alphabetically
        contacts.sort { person1, person2 in
            let name1 = person1.displayName ?? person1.contactIdentifier
            let name2 = person2.displayName ?? person2.contactIdentifier
            
            if sortOrder == .ascending {
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            } else {
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedDescending
            }
        }
        
        return contacts
    }
    
    func toggleSortOrder() {
        sortOrder = sortOrder == .ascending ? .descending : .ascending
    }
    
    func toggleTagSelection(_ tagId: UUID) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
    }
    
    func clearFilters() {
        selectedTagIds.removeAll()
    }
    
    func tagsForPerson(_ personId: UUID) -> [Tag] {
        let tagIds = personTags
            .filter { $0.personId == personId }
            .map { $0.tagId }
        
        return allTags.filter { tagIds.contains($0.id) }
    }
}