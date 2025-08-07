import SwiftUI
import OrbitsKit

struct OrbitsView: View {
    @StateObject private var viewModel: OrbitsViewModel
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var showingSettings = false
    @State private var sortOption: SortOption = .leastOverdue
    @State private var filterOption: FilterOption = .all
    @State private var randomizedPeopleIds: [UUID]? = nil
    @State private var selectedPerson: Person? = nil
    
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
                if viewModel.isLoading && viewModel.peopleNeedingAttention.isEmpty {
                    // Show skeleton loading UI
                    ForEach(0..<6, id: \.self) { _ in
                        ContactCardSkeleton()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if viewModel.filteredPeople.isEmpty && !viewModel.isLoading {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                } else {
                    ForEach(viewModel.filteredPeople, id: \.id) { person in
                        SwipeableContactCard(
                            person: person,
                            tags: viewModel.personTags[person.id] ?? [],
                            onTap: {
                                selectedPerson = person
                            },
                            onMessage: {
                                openMessagesApp(for: person)
                            },
                            onRemoveOrbit: {
                                await viewModel.removeOrbit(from: person)
                            },
                            onSnooze: {
                                await viewModel.snooze(person: person, days: 3)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .onAppear {
                            // Load more when reaching last few items
                            if let index = viewModel.filteredPeople.firstIndex(where: { $0.id == person.id }),
                               index >= viewModel.filteredPeople.count - 3 {
                                Task {
                                    await viewModel.loadMoreData()
                                }
                            }
                        }
                    }
                    
                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
        }
        .listStyle(PlainListStyle())
        .background(
            NavigationLink(
                destination: Group {
                    if let person = selectedPerson {
                        ContactDetailView(person: person, supabaseService: viewModel.supabaseService)
                    }
                },
                isActive: Binding(
                    get: { selectedPerson != nil },
                    set: { if !$0 { selectedPerson = nil } }
                )
            ) {
                EmptyView()
            }
        )
        .navigationTitle("Orbits")
        .searchable(text: $searchText, prompt: "Search contacts")
        .onChange(of: searchText) { _ in
            viewModel.updateSearchText(searchText)
        }
        .onChange(of: sortOption) { _ in
            viewModel.updateSortOption(sortOption)
        }
        .onChange(of: filterOption) { _ in
            viewModel.updateFilterOption(filterOption)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            filterSheet
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .refreshable {
            // Create new randomization on refresh
            if viewModel.peopleNeedingAttention.count > 10 {
                randomizedPeopleIds = viewModel.peopleNeedingAttention.shuffled().map { $0.id }
            } else {
                randomizedPeopleIds = nil
            }
            await viewModel.loadData(forceRefresh: true)
        }
        .onAppear {
            Task {
                await viewModel.loadData()
                // Set initial randomization if needed
                if randomizedPeopleIds == nil && viewModel.peopleNeedingAttention.count > 10 {
                    randomizedPeopleIds = viewModel.peopleNeedingAttention.shuffled().map { $0.id }
                }
            }
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
    
    private func openMessagesApp(for person: Person) {
        let contactIdentifier = person.phoneNumber ?? person.emailAddress ?? person.contactIdentifier
        
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