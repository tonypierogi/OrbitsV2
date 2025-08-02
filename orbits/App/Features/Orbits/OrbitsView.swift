import SwiftUI
import OrbitsKit

struct OrbitsView: View {
    @StateObject private var viewModel: OrbitsViewModel
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var sortOption: SortOption = .leastOverdue
    @State private var filterOption: FilterOption = .all
    
    enum SortOption: String, CaseIterable {
        case mostOverdue = "Most Overdue"
        case leastOverdue = "Least Overdue"
        case name = "Name"
        case lastContact = "Last Contact"
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case nearOrbit = "Near Orbit"
        case middleOrbit = "Middle Orbit"
        case farOrbit = "Far Orbit"
        case outerOrbit = "Outer Orbit"
    }
    
    init(supabaseService: SupabaseService) {
        self._viewModel = StateObject(wrappedValue: OrbitsViewModel(supabaseService: supabaseService))
    }
    
    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if sortedAndFilteredPeople.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            } else {
                ForEach(sortedAndFilteredPeople, id: \.id) { person in
                    ContactCard(person: person, onTap: {
                        // Navigation handled by background NavigationLink
                    }, onMessage: {
                        openMessagesApp(for: person)
                    })
                    .background(
                        NavigationLink(destination: ContactDetailView(person: person, supabaseService: viewModel.supabaseService)) {
                            EmptyView()
                        }
                        .opacity(0)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.removeOrbit(from: person)
                            }
                        } label: {
                            Label("Remove Orbit", systemImage: "xmark.circle")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            Task {
                                await viewModel.snooze(person: person, days: 3)
                            }
                        } label: {
                            Label("Snooze 3 Days", systemImage: "moon.zzz")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Orbits")
        .searchable(text: $searchText, prompt: "Search contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            filterSheet
        }
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("All Caught Up!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No contacts need attention right now")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    
    @ViewBuilder
    private var filterSheet: some View {
        NavigationView {
            Form {
                Section("Sort By") {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.rawValue)
                            Spacer()
                            if sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sortOption = option
                        }
                    }
                }
                
                Section("Filter By Orbit") {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.rawValue)
                            Spacer()
                            if filterOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            filterOption = option
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterSheet = false
                    }
                }
            }
        }
    }
    
    private var sortedAndFilteredPeople: [Person] {
        let filtered = filteredPeople
        
        switch sortOption {
        case .mostOverdue:
            return filtered.sorted { person1, person2 in
                let days1 = daysSinceLastContact(for: person1) ?? 0
                let days2 = daysSinceLastContact(for: person2) ?? 0
                return days1 > days2
            }
        case .leastOverdue:
            return filtered.sorted { person1, person2 in
                let days1 = daysSinceLastContact(for: person1) ?? 0
                let days2 = daysSinceLastContact(for: person2) ?? 0
                return days1 < days2
            }
        case .name:
            return filtered.sorted { person1, person2 in
                let name1 = person1.displayName ?? person1.contactIdentifier
                let name2 = person2.displayName ?? person2.contactIdentifier
                return name1 < name2
            }
        case .lastContact:
            return filtered.sorted { person1, person2 in
                let date1 = person1.lastMessageAt ?? Date.distantPast
                let date2 = person2.lastMessageAt ?? Date.distantPast
                return date1 < date2
            }
        }
    }
    
    private var filteredPeople: [Person] {
        var people = viewModel.peopleNeedingAttention
        
        // Apply orbit filter
        switch filterOption {
        case .all:
            break
        case .nearOrbit:
            people = people.filter { $0.orbit?.name == "Near" }
        case .middleOrbit:
            people = people.filter { $0.orbit?.name == "Middle" }
        case .farOrbit:
            people = people.filter { $0.orbit?.name == "Far" }
        case .outerOrbit:
            people = people.filter { $0.orbit?.name == "Outer" }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            people = people.filter { person in
                let name = person.displayName ?? person.contactIdentifier
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return people
    }
    
    private func daysSinceLastContact(for person: Person) -> Int? {
        guard let lastMessageDate = person.lastMessageAt else { return nil }
        return Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day
    }
    
    private func openMessagesApp(for person: Person) {
        let contactIdentifier = person.contactIdentifier
        
        // Clean phone number (remove non-numeric characters except +)
        let cleanedIdentifier = contactIdentifier.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        if let url = URL(string: "sms:\(cleanedIdentifier)") {
            UIApplication.shared.open(url)
        }
    }
}

struct OrbitsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OrbitsView(supabaseService: SupabaseService(client: SupabaseManager.shared.client))
        }
    }
}