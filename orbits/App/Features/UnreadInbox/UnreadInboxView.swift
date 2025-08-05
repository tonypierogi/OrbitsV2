import SwiftUI
import OrbitsKit

struct UnreadInboxView: View {
    @StateObject private var viewModel = UnreadInboxViewModel()
    @State private var showingSortMenu = false
    @State private var showingFilterMenu = false
    @State private var showingSettings = false
    @State private var searchText = ""
    
    private var filteredContacts: [Person] {
        guard !searchText.isEmpty else { return viewModel.unreadContacts }
        
        return viewModel.unreadContacts.filter { person in
            // Search in display name and contact identifier
            let name = person.displayName ?? person.contactIdentifier
            if name.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search in tags
            if let tags = viewModel.personTags[person.id] {
                for tag in tags {
                    if tag.label.localizedCaseInsensitiveContains(searchText) {
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    var body: some View {
        List {
            if filteredContacts.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Unread Messages" : "No Results", 
                    systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Messages from your contacts will appear here" : "Try a different search term")
                )
            } else {
                ForEach(filteredContacts) { person in
                    NavigationLink(destination: ContactDetailView(
                        person: person,
                        supabaseService: viewModel.supabaseService
                    )) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                // Name
                                Text(person.displayName ?? person.contactIdentifier)
                                    .font(.headline)
                                
                                // Status indicator
                                if person.needsResponse {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.orange)
                                        Text("Marked for response")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                } else if person.unreadCount > 0 {
                                    if let lastMessageDate = person.lastMessageAt {
                                        let days = Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day ?? 0
                                        Text("Unread for \(days) day\(days == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("Unread messages")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                // Tags
                                if let tags = viewModel.personTags[person.id], !tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(tags.prefix(3)) { tag in
                                                Text(tag.label)
                                                    .font(.system(size: 11))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundColor(.blue)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            if tags.count > 3 {
                                                Text("+\(tags.count - 3)")
                                                    .font(.system(size: 11))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.1))
                                                    .foregroundColor(.gray)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Message button
                            Button(action: {
                                openMessages(for: person)
                            }) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .frame(width: 36, height: 36)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Inbox")
        .searchable(text: $searchText, prompt: "Search contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort button
                    Menu {
                        ForEach(UnreadInboxViewModel.SortOption.allCases, id: \.self) { option in
                            Button(action: { viewModel.setSortOption(option) }) {
                                Label(option.rawValue, systemImage: option.icon)
                                    .foregroundColor(viewModel.sortOption == option ? .blue : .primary)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
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
            FilterMenuView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadUnreadContacts()
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        !viewModel.selectedOrbitIds.isEmpty ||
        !viewModel.selectedTagIds.isEmpty ||
        !viewModel.selectedCategoryIds.isEmpty
    }
    
    private func openMessages(for person: Person) {
        let identifier = person.contactIdentifier
        var urlString = "sms:"
        
        // Check if it's a phone number or email
        if identifier.contains("@") {
            // Email - use the email directly
            urlString += identifier
        } else {
            // Phone number - clean it up
            let cleanedNumber = identifier.filter { $0.isNumber || $0 == "+" }
            urlString += cleanedNumber
        }
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

struct FilterMenuView: View {
    @ObservedObject var viewModel: UnreadInboxViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Orbits section
                if !viewModel.availableOrbits.isEmpty {
                    Section("Orbits") {
                        ForEach(viewModel.availableOrbits) { orbit in
                            HStack {
                                Text(orbit.name)
                                Spacer()
                                if viewModel.selectedOrbitIds.contains(orbit.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleOrbitFilter(orbit.id)
                            }
                        }
                    }
                }
                
                // Categories section
                if !viewModel.availableCategories.isEmpty {
                    Section("Categories") {
                        ForEach(viewModel.availableCategories) { category in
                            HStack {
                                Text(category.name)
                                Spacer()
                                if viewModel.selectedCategoryIds.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleCategoryFilter(category.id)
                            }
                        }
                    }
                }
                
                // Tags section
                if !viewModel.availableTags.isEmpty {
                    Section("Tags") {
                        ForEach(viewModel.availableTags) { tag in
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
                                viewModel.toggleTagFilter(tag.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        viewModel.clearAllFilters()
                    }
                    .disabled(!hasActiveFilters)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        !viewModel.selectedOrbitIds.isEmpty ||
        !viewModel.selectedTagIds.isEmpty ||
        !viewModel.selectedCategoryIds.isEmpty
    }
}