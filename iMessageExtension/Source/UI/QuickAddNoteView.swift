import SwiftUI
import OrbitsKit
import Messages

struct QuickAddNoteView: View {
    let conversation: MSConversation?
    weak var extensionContext: NSExtensionContext?
    let remoteParticipantId: String?
    
    @State private var noteText = ""
    @State private var todoText = ""
    @State private var isCreating = false
    @State private var isCreatingTodo = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var contactPerson: Person?
    @State private var isLoadingContact = false
    @State private var isAuthenticated = false
    @State private var showingPersonPicker = false
    @State private var allPersons: [Person] = []
    @State private var isLoadingPersons = false
    @State private var isLoadingConversationLink = false
    @State private var hasAttemptedLoad = false
    
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    private let authManager = AuthManager()
    
    var displayName: String {
        if let person = contactPerson {
            return person.displayName ?? person.contactIdentifier
        }
        return "Select Contact"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact Header
            HStack(spacing: 16) {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Add Note")
                        .font(.system(size: 14, weight: .semibold))
                    
                    // Contact selection button
                    Button(action: {
                        showingPersonPicker = true
                    }) {
                        HStack(spacing: 4) {
                            if isLoadingPersons || isLoadingConversationLink {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text(isLoadingConversationLink ? "Loading contact..." : "Loading...")
                                    .font(.system(size: 12))
                            } else {
                                Image(systemName: contactPerson == nil ? "person.badge.plus" : "person.fill")
                                    .font(.system(size: 11))
                                Text(displayName)
                                    .font(.system(size: 12))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .foregroundColor(contactPerson == nil ? .blue : .primary)
                    .disabled(isLoadingPersons || isLoadingConversationLink)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            if !isAuthenticated {
                // Not authenticated view
                VStack(spacing: 16) {
                    Image(systemName: "lock.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Please sign in to Orbits")
                        .font(.headline)
                    
                    Text("Open the Orbits app to sign in and sync your contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: openMainApp) {
                        Label("Open Orbits", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            } else {
                // Authenticated view - Note and Todo inputs
                VStack(spacing: 12) {
                    // Note input
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                            Text("Note")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        TextField("Add a note...", text: $noteText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...3)
                        
                        if !noteText.isEmpty {
                            Button(action: {
                                Task {
                                    await createQuickNote()
                                }
                            }) {
                                HStack {
                                    Text("Save Note")
                                        .font(.system(size: 13))
                                    if isCreating {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .disabled(isCreating)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Todo input
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checklist")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("Todo")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        TextField("Add a todo...", text: $todoText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...2)
                        
                        if !todoText.isEmpty {
                            Button(action: {
                                Task {
                                    await createQuickTodo()
                                }
                            }) {
                                HStack {
                                    Text("Save Todo")
                                        .font(.system(size: 13))
                                    if isCreatingTodo {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .disabled(isCreatingTodo)
                        }
                    }
                    .padding(.horizontal)
                }
            
            Spacer()
            
                // Open app button - more subtle
                HStack {
                    Spacer()
                    Button(action: openMainApp) {
                        HStack(spacing: 4) {
                            Text("Open Orbits")
                                .font(.system(size: 11))
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
            } // End of else (authenticated)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                // Clear the appropriate field but keep the contact selected
                if successMessage.contains("Note") {
                    noteText = ""
                } else {
                    todoText = ""
                }
                // Don't clear contactPerson - keep it selected
            }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            // Use .task for better async handling
            await initializeView()
        }
        .onAppear {
            // Retry if we haven't loaded yet and have a remote ID
            if !hasAttemptedLoad && remoteParticipantId != nil {
                Task {
                    await initializeView()
                }
            }
        }
        .sheet(isPresented: $showingPersonPicker) {
            PersonPickerView(
                selectedPerson: $contactPerson,
                persons: allPersons
            )
        }
        .onChange(of: contactPerson) { oldValue, newValue in
            Task {
                await saveConversationLink(for: newValue)
            }
        }
    }
    
    private func loadPersons() async {
        isLoadingPersons = true
        print("Starting to load persons...")
        do {
            allPersons = try await supabaseService.fetchPersons()
            print("Loaded \(allPersons.count) persons")
            for person in allPersons.prefix(3) {
                print("  - \(person.displayName ?? person.contactIdentifier)")
            }
        } catch {
            print("Failed to load persons: \(error)")
        }
        isLoadingPersons = false
    }
    
    private func checkAuthentication() async {
        // Give auth storage a moment to load from app group
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        isAuthenticated = authManager.session != nil
        print("Authentication check: \(isAuthenticated ? "Authenticated" : "Not authenticated")")
        if isAuthenticated {
            print("User ID: \(authManager.session?.user.id.uuidString ?? "No user ID")")
        } else {
            // Try to get current session from Supabase directly
            let session = SupabaseManager.shared.client.auth.currentSession
            if session != nil {
                isAuthenticated = true
                print("Found session directly from Supabase client")
            }
        }
    }
    
    private func initializeView() async {
        print("[QuickAddNote] initializeView called")
        print("[QuickAddNote] Remote participant ID on init: \(remoteParticipantId ?? "nil")")
        
        hasAttemptedLoad = true
        await checkAuthentication()
        
        if isAuthenticated {
            print("[QuickAddNote] User is authenticated, loading data...")
            // Load persons first
            await loadPersons()
            
            // Try to load conversation link with retry
            await loadConversationLinkWithRetry()
        } else {
            print("[QuickAddNote] User not authenticated, skipping data load")
        }
    }
    
    private func createQuickNote() async {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        defer { isCreating = false }
        
        do {
            _ = try await supabaseService.createNote(
                personId: contactPerson?.id,
                type: .note,
                text: noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Save conversation link if we have a person selected and a remote participant ID
            if let personId = contactPerson?.id, let remoteId = remoteParticipantId {
                try? await supabaseService.createOrUpdateConversationLink(
                    iosUuid: remoteId,
                    personId: personId
                )
            }
            
            await MainActor.run {
                successMessage = "Note created successfully!"
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create note: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func createQuickTodo() async {
        guard !todoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreatingTodo = true
        defer { isCreatingTodo = false }
        
        do {
            _ = try await supabaseService.createNote(
                personId: contactPerson?.id,
                type: .todo,
                text: todoText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Save conversation link if we have a person selected and a remote participant ID
            if let personId = contactPerson?.id, let remoteId = remoteParticipantId {
                try? await supabaseService.createOrUpdateConversationLink(
                    iosUuid: remoteId,
                    personId: personId
                )
            }
            
            await MainActor.run {
                successMessage = "Todo created successfully!"
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create todo: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func loadConversationLinkWithRetry() async {
        print("[QuickAddNote] loadConversationLinkWithRetry called")
        // Try up to 3 times with delay if no remote ID
        for attempt in 1...3 {
            if let remoteId = remoteParticipantId {
                print("[QuickAddNote] Attempt \(attempt): Have remote ID, loading conversation link")
                await loadConversationLink(remoteId: remoteId)
                break
            } else {
                print("[QuickAddNote] Attempt \(attempt): No remote participant ID available yet")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
            }
        }
    }
    
    private func loadConversationLink(remoteId: String) async {
        print("[QuickAddNote] Loading conversation link for remote ID: \(remoteId)")
        print("[QuickAddNote] Remote ID (original): \(remoteId)")
        print("[QuickAddNote] Remote ID (lowercase): \(remoteId.lowercased())")
        isLoadingConversationLink = true
        
        do {
            if let link = try await supabaseService.fetchConversationLink(for: remoteId) {
                print("[QuickAddNote] Found conversation link for person ID: \(link.personId)")
                print("[QuickAddNote] Current allPersons count: \(allPersons.count)")
                
                // Find the person in our loaded persons array
                if let person = allPersons.first(where: { $0.id == link.personId }) {
                    await MainActor.run {
                        contactPerson = person
                    }
                    print("[QuickAddNote] Successfully loaded conversation link for person: \(person.displayName ?? person.contactIdentifier)")
                } else {
                    print("[QuickAddNote] Person with ID \(link.personId) not found in allPersons array")
                    print("[QuickAddNote] All person IDs in array: \(allPersons.map { $0.id.uuidString })")
                    // Try to fetch this specific person
                    if let person = try await supabaseService.fetchPerson(by: link.personId) {
                        await MainActor.run {
                            // Add to our persons array and set as selected
                            if !allPersons.contains(where: { $0.id == person.id }) {
                                allPersons.append(person)
                            }
                            contactPerson = person
                        }
                        print("[QuickAddNote] Fetched and loaded person: \(person.displayName ?? person.contactIdentifier)")
                    } else {
                        print("[QuickAddNote] Failed to fetch person with ID: \(link.personId)")
                    }
                }
            } else {
                print("[QuickAddNote] No conversation link found for remote ID: \(remoteId)")
            }
        } catch {
            print("[QuickAddNote] Failed to load conversation link: \(error)")
        }
        
        isLoadingConversationLink = false
    }
    
    private func saveConversationLink(for person: Person?) async {
        guard let remoteId = remoteParticipantId else {
            print("Cannot save conversation link: no remote participant ID")
            return
        }
        
        print("Saving conversation link for remote ID: \(remoteId)")
        
        do {
            if let person = person {
                // Save the link when a person is selected
                try await supabaseService.createOrUpdateConversationLink(
                    iosUuid: remoteId,
                    personId: person.id
                )
                print("Successfully saved conversation link for person: \(person.displayName ?? person.contactIdentifier) with ID: \(person.id)")
            } else {
                // Delete the link when person is cleared
                try await supabaseService.deleteConversationLink(for: remoteId)
                print("Deleted conversation link for remote ID: \(remoteId)")
            }
        } catch {
            print("Failed to save conversation link: \(error)")
        }
    }
    
    private func openMainApp() {
        guard let url = URL(string: "orbits://") else { return }
        
        // Use the extension context passed from MessagesViewController
        extensionContext?.open(url) { success in
            if !success {
                print("Failed to open URL: \(url)")
            }
        }
    }
}

#Preview {
    QuickAddNoteView(conversation: nil, extensionContext: nil, remoteParticipantId: nil)
}