import SwiftUI
import OrbitsKit

struct ContactDetailView: View {
    @StateObject private var viewModel: ContactDetailViewModel
    @State private var selectedOrbit: Orbit?
    @State private var showingOrbitPicker = false
    @State private var showingAddNote = false
    @State private var newNoteText = ""
    
    init(person: Person, supabaseService: SupabaseService) {
        self._viewModel = StateObject(wrappedValue: ContactDetailViewModel(person: person, supabaseService: supabaseService))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Contact Header
                contactHeader
                
                // Orbit Assignment
                orbitSection
                
                // Contact Info
                contactInfoSection
                
                // Message Activity
                messageActivitySection
                
                // Notes Section
                notesSection
                
                // Tags Section
                tagsSection
            }
            .padding()
        }
        .navigationTitle(viewModel.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddNote = true }) {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                    }
                    Button(action: viewModel.markContacted) {
                        Label("Mark as Contacted", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingOrbitPicker) {
            orbitPickerSheet
        }
        .sheet(isPresented: $showingAddNote) {
            addNoteSheet
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    @ViewBuilder
    private var contactHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Text(viewModel.initials)
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Name and identifier
            VStack(spacing: 4) {
                Text(viewModel.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if viewModel.person.displayName != nil {
                    Text(viewModel.person.contactIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status badges
            HStack(spacing: 12) {
                if let lastContact = viewModel.lastContactText {
                    Label(lastContact, systemImage: "clock")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if viewModel.person.unreadCount > 0 {
                    Label("\(viewModel.person.unreadCount) unread", systemImage: "envelope.badge")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private var orbitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Orbit", systemImage: "circle.circle")
                .font(.headline)
            
            Button(action: { showingOrbitPicker = true }) {
                HStack {
                    if let orbit = viewModel.currentOrbit {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(orbit.name)
                                .font(.body)
                            Text("Check in every \(orbit.intervalDays) days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Assign to orbit")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            if let statusText = viewModel.orbitStatusText {
                HStack {
                    Image(systemName: viewModel.isOverdue ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(viewModel.isOverdue ? .red : .green)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(viewModel.isOverdue ? .red : .green)
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var contactInfoSection: some View {
        if !viewModel.contactMethods.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Contact Info", systemImage: "person.text.rectangle")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    ForEach(viewModel.contactMethods, id: \.self) { method in
                        HStack {
                            Image(systemName: method.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(method.value)
                                .font(.body)
                            
                            Spacer()
                            
                            Button(action: { method.action() }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var messageActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Message Activity", systemImage: "message")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if let lastMessageDate = viewModel.person.lastMessageAt {
                    HStack {
                        Text("Last message")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastMessageDate, style: .relative)
                    }
                    .font(.subheadline)
                }
                
                HStack {
                    Text("Unread messages")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.person.unreadCount)")
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Notes", systemImage: "note.text")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddNote = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if viewModel.notes.isEmpty {
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.notes) { note in
                        NoteRow(note: note)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tags", systemImage: "tag")
                    .font(.headline)
                
                Spacer()
                
                Button(action: viewModel.addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if viewModel.tags.isEmpty {
                Text("No tags")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.tags) { tag in
                        TagChip(tag: tag) {
                            await viewModel.removeTag(tag)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var orbitPickerSheet: some View {
        NavigationView {
            List(viewModel.availableOrbits) { orbit in
                Button(action: {
                    Task {
                        await viewModel.assignToOrbit(orbit)
                        showingOrbitPicker = false
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(orbit.name)
                                .font(.headline)
                            Text("Every \(orbit.intervalDays) days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if orbit.id == viewModel.currentOrbit?.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Orbit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingOrbitPicker = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var addNoteSheet: some View {
        NavigationView {
            VStack {
                TextEditor(text: $newNoteText)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        newNoteText = ""
                        showingAddNote = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addNote(newNoteText)
                            newNoteText = ""
                            showingAddNote = false
                        }
                    }
                    .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct NoteRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(.subheadline)
            
            HStack {
                Text(note.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if note.type == .todo {
                    Label("Todo", systemImage: "checklist")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct TagChip: View {
    let tag: Tag
    let onDelete: () async -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag.label)
                .font(.caption)
            
            Button(action: { Task { await onDelete() } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(20)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                self.size.width = max(self.size.width, x - spacing)
            }
            
            self.size.height = y + lineHeight
        }
    }
}

struct ContactDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContactDetailView(
                person: Person(
                    userId: UUID(),
                    contactIdentifier: "john@example.com",
                    displayName: "John Doe",
                    orbitId: UUID(),
                    unreadCount: 3,
                    lastMessageAt: Date().addingTimeInterval(-86400 * 5),
                    orbit: Orbit(
                        userId: UUID(),
                        name: "Near",
                        intervalDays: 14,
                        slackDays: 7,
                        position: 1
                    )
                ),
                supabaseService: SupabaseService(client: SupabaseManager.shared.client)
            )
        }
    }
}