import Foundation
import OrbitsKit

@MainActor
class OrbitsViewModel: ObservableObject {
    @Published var orbits: [Orbit] = []
    @Published var peopleNeedingAttention: [Person] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var personTags: [UUID: [Tag]] = [:]
    @Published var hasMoreData = true
    @Published var filteredPeople: [Person] = []
    
    let supabaseService: SupabaseService
    
    // Track snoozed people during this session
    private var snoozedPeople: Set<UUID> = []
    private var snoozeExpirations: [UUID: Date] = [:]
    
    // Pagination
    private var currentOffset = 0
    private let pageSize = 30
    
    // Caching
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    private var allFetchedPeople: [Person] = [] // Keep all fetched people for filtering
    
    // Filtering and sorting
    private var searchText = ""
    private var sortOption: OrbitsView.SortOption = .leastOverdue
    private var filterOption: OrbitsView.FilterOption = .all
    private var randomizedPeopleIds: [UUID]? = nil
    
    // Memoization
    private var lastFilterParams: (search: String, sort: OrbitsView.SortOption, filter: OrbitsView.FilterOption)?
    private var lastFilteredResult: [Person] = []
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    func loadData(forceRefresh: Bool = false) async {
        // Check cache if not forcing refresh
        if !forceRefresh, let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < cacheDuration {
            return // Use cached data
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Reset pagination
        currentOffset = 0
        hasMoreData = true
        allFetchedPeople = []
        
        do {
            // Load orbits first (usually small dataset)
            let fetchedOrbits = try await supabaseService.fetchOrbits()
            self.orbits = fetchedOrbits.sorted { $0.position < $1.position }
            
            // Load first page of people needing attention
            let fetchedPeople = try await supabaseService.fetchPersonsNeedingAttentionOptimized(
                limit: pageSize,
                offset: currentOffset
            )
            
            self.allFetchedPeople = fetchedPeople
            self.peopleNeedingAttention = filterAndSortPeople(fetchedPeople)
            self.hasMoreData = fetchedPeople.count == pageSize
            self.currentOffset += fetchedPeople.count
            
            // Apply filters
            updateFilteredPeople()
            
            // Update cache timestamp
            self.lastFetchTime = Date()
            
            // Clear tags for now - will load lazily
            self.personTags = [:]
        } catch {
            print("Error loading orbits data: \(error)")
        }
    }
    
    func loadMoreData() async {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let morePeople = try await supabaseService.fetchPersonsNeedingAttentionOptimized(
                limit: pageSize,
                offset: currentOffset
            )
            
            if morePeople.isEmpty {
                hasMoreData = false
            } else {
                allFetchedPeople.append(contentsOf: morePeople)
                peopleNeedingAttention = filterAndSortPeople(allFetchedPeople)
                currentOffset += morePeople.count
                hasMoreData = morePeople.count == pageSize
                
                // Apply filters
                updateFilteredPeople()
            }
        } catch {
            print("Error loading more data: \(error)")
        }
    }
    
    private func filterAndSortPeople(_ people: [Person]) -> [Person] {
        let filtered = people.filter { person in
            // Check if person is snoozed
            if let expirationDate = snoozeExpirations[person.id] {
                if Date() < expirationDate {
                    return false
                } else {
                    // Snooze expired, remove from tracking
                    snoozedPeople.remove(person.id)
                    snoozeExpirations.removeValue(forKey: person.id)
                }
            }
            return true
        }
        
        // Sort by most overdue first
        return filtered.sorted { person1, person2 in
            let days1 = daysSinceLastContact(for: person1) ?? 0
            let days2 = daysSinceLastContact(for: person2) ?? 0
            return days1 > days2
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
            // Invalidate cache and update the filtered list to reflect the change
            invalidateFilterCache()
            updateFilteredPeople()
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
            
            // Remove from all local lists and update filtered view
            await MainActor.run {
                peopleNeedingAttention.removeAll { $0.id == person.id }
                allFetchedPeople.removeAll { $0.id == person.id }
                // Invalidate cache and update the filtered list to reflect the change
                invalidateFilterCache()
                updateFilteredPeople()
            }
        } catch {
            print("Error removing orbit: \(error)")
            print("Person ID: \(person.id.uuidString)")
        }
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        updateFilteredPeople()
    }
    
    func updateSortOption(_ option: OrbitsView.SortOption) {
        sortOption = option
        updateFilteredPeople()
    }
    
    func updateFilterOption(_ option: OrbitsView.FilterOption) {
        filterOption = option
        updateFilteredPeople()
    }
    
    private func invalidateFilterCache() {
        lastFilterParams = nil
        lastFilteredResult = []
    }
    
    private func updateFilteredPeople() {
        // Check if we can use memoized result
        let currentParams = (search: searchText, sort: sortOption, filter: filterOption)
        if let lastParams = lastFilterParams,
           lastParams.search == currentParams.search,
           lastParams.sort == currentParams.sort,
           lastParams.filter == currentParams.filter {
            // Use cached result
            filteredPeople = lastFilteredResult
            return
        }
        
        // Filter people
        var filtered = peopleNeedingAttention
        
        // Apply orbit filter
        switch filterOption {
        case .all:
            break
        case .nearOrbit:
            filtered = filtered.filter { $0.orbit?.name == "Near" }
        case .middleOrbit:
            filtered = filtered.filter { $0.orbit?.name == "Middle" }
        case .farOrbit:
            filtered = filtered.filter { $0.orbit?.name == "Far" }
        case .outerOrbit:
            filtered = filtered.filter { $0.orbit?.name == "Outer" }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { person in
                // Search in display name and contact identifier
                let name = person.displayName ?? person.contactIdentifier
                if name.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search in tags - skip for now as tags aren't loaded
                // TODO: Implement tag search when tags are loaded
                
                return false
            }
        }
        
        // Sort people
        let sorted: [Person]
        switch sortOption {
        case .mostOverdue:
            sorted = filtered.sorted { person1, person2 in
                let days1 = daysSinceLastContact(for: person1) ?? 0
                let days2 = daysSinceLastContact(for: person2) ?? 0
                return days1 > days2
            }
        case .leastOverdue:
            sorted = filtered.sorted { person1, person2 in
                let days1 = daysSinceLastContact(for: person1) ?? 0
                let days2 = daysSinceLastContact(for: person2) ?? 0
                return days1 < days2
            }
        case .name:
            sorted = filtered.sorted { person1, person2 in
                let name1 = person1.displayName ?? person1.contactIdentifier
                let name2 = person2.displayName ?? person2.contactIdentifier
                return name1 < name2
            }
        case .lastContact:
            sorted = filtered.sorted { person1, person2 in
                let date1 = person1.lastMessageAt ?? Date.distantPast
                let date2 = person2.lastMessageAt ?? Date.distantPast
                return date1 < date2
            }
        }
        
        // Limit to 10 if needed (with randomization)
        let finalResult: [Person]
        if sorted.count > 10 {
            // Create randomization if needed
            if randomizedPeopleIds == nil {
                randomizedPeopleIds = sorted.shuffled().map { $0.id }
            }
            
            // Use existing randomization
            if let existingIds = randomizedPeopleIds {
                let selectedIds = existingIds.filter { id in sorted.contains { $0.id == id } }
                finalResult = sorted.filter { person in
                    selectedIds.prefix(10).contains(person.id)
                }
            } else {
                finalResult = Array(sorted.prefix(10))
            }
        } else {
            finalResult = sorted
        }
        
        // Cache the result
        lastFilterParams = currentParams
        lastFilteredResult = finalResult
        filteredPeople = finalResult
    }
}