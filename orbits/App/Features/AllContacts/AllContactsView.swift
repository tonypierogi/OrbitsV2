import SwiftUI
import OrbitsKit

struct AllContactsView: View {
    @StateObject private var viewModel = AllContactsViewModel()
    @State private var searchText = ""
    @State private var showingFilterMenu = false
    @State private var showingSettings = false
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    
    private var filteredContacts: [Person] {
        let contacts = viewModel.filteredAndSortedContacts
        
        guard !searchText.isEmpty else { return contacts }
        
        return contacts.filter { person in
            // Search in display name
            if let displayName = person.displayName,
               displayName.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search in contact identifier
            if person.contactIdentifier.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search in phone number
            if let phoneNumber = person.phoneNumber,
               phoneNumber.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search in email
            if let email = person.emailAddress,
               email.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            return false
        }
    }
    
    private var hasActiveFilters: Bool {
        !viewModel.selectedTagIds.isEmpty
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.headline)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        Task {
                            await viewModel.loadData()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if filteredContacts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty && !hasActiveFilters ? "person.2" : "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty && !hasActiveFilters ? "No Contacts" : "No Results")
                        .font(.headline)
                    Text(searchText.isEmpty && !hasActiveFilters ? "Add some contacts to get started" : "Try a different search term or adjust filters")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List {
                    ForEach(filteredContacts) { person in
                        ContactCard(
                            person: person,
                            tags: viewModel.tagsForPerson(person.id),
                            onTap: {
                                // Navigation handled by background NavigationLink
                            },
                            onMessage: {
                                openMessagesApp(for: person)
                            }
                        )
                        .background(
                            NavigationLink(destination: ContactDetailView(person: person, supabaseService: supabaseService)) {
                                EmptyView()
                            }
                            .opacity(0)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.loadData()
                }
            }
        }
        .navigationTitle("Contacts")
        .searchable(text: $searchText, prompt: "Search contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort button
                    Button(action: { viewModel.toggleSortOrder() }) {
                        Image(systemName: viewModel.sortOrder == .ascending ? "arrow.up" : "arrow.down")
                            .foregroundColor(.blue)
                    }
                    
                    // Filter button
                    Button(action: { showingFilterMenu = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(hasActiveFilters ? .blue : .gray)
                    }
                    
                    // Settings button
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterMenu) {
            ContactsFilterView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            await viewModel.loadData()
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

struct ContactsFilterView: View {
    @ObservedObject var viewModel: AllContactsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Tags section
                if !viewModel.allTags.isEmpty {
                    Section("Tags") {
                        ForEach(viewModel.allTags) { tag in
                            HStack {
                                Text(tag.label)
                                Spacer()
                                if viewModel.selectedTagIds.contains(tag.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleTagSelection(tag.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .disabled(viewModel.selectedTagIds.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}