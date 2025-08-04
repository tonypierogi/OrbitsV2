import SwiftUI
import OrbitsKit

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NotesViewModel
    @State private var isEditing = false
    @State private var linkedPerson: Person?
    @State private var currentNote: Note
    @State private var showingDeleteAlert = false
    
    private let supabaseService: SupabaseService
    
    init(viewModel: NotesViewModel, note: Note) {
        self.viewModel = viewModel
        self._currentNote = State(initialValue: note)
        self.supabaseService = viewModel.supabaseService
    }
    
    var noteTitle: String {
        let lines = currentNote.text.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespaces) ?? "Untitled"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Note content
                VStack(alignment: .leading, spacing: 12) {
                    Text(currentNote.text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Created", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentNote.createdAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if currentNote.updatedAt != currentNote.createdAt {
                            HStack {
                                Label("Updated", systemImage: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(currentNote.updatedAt, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if currentNote.type == .todo {
                            HStack {
                                Label("Status", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(currentNote.status == .open ? "Open" : "Completed")
                                    .font(.caption)
                                    .foregroundColor(currentNote.status == .open ? .orange : .green)
                            }
                            
                            if let dueAt = currentNote.dueAt {
                                HStack {
                                    Label("Due", systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(dueAt, style: .date)
                                        .font(.caption)
                                        .foregroundColor(dueAt < Date() && currentNote.status == .open ? .red : .secondary)
                                }
                            }
                        }
                        
                        if let person = linkedPerson {
                            HStack {
                                Label("Person", systemImage: "person")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(person.displayName ?? person.contactIdentifier)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .navigationTitle(noteTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    if currentNote.type == .todo && currentNote.status == .open {
                        Button {
                            Task {
                                await viewModel.updateNoteStatus(currentNote, newStatus: .closed)
                                dismiss()
                            }
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            if let personId = currentNote.personId {
                await loadLinkedPerson(personId)
            }
        }
        .sheet(isPresented: $isEditing) {
            EditNoteView(viewModel: viewModel, note: currentNote)
                .onDisappear {
                    // Refresh the view when returning from edit
                    Task {
                        await viewModel.loadNotes()
                        // Update current note with the edited version
                        if let updatedNote = viewModel.notes.first(where: { $0.id == currentNote.id }) {
                            currentNote = updatedNote
                        }
                    }
                }
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteNote(currentNote)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this \(currentNote.type == .note ? "note" : "todo")? This action cannot be undone.")
        }
    }
    
    private func loadLinkedPerson(_ personId: UUID) async {
        do {
            let persons = try await supabaseService.fetchPersons()
            linkedPerson = persons.first { $0.id == personId }
        } catch {
            print("Failed to load linked person: \(error)")
        }
    }
}