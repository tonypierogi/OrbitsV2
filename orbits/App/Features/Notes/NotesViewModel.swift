import SwiftUI
import OrbitsKit

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let supabaseService: SupabaseService
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    func loadNotes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            notes = try await supabaseService.fetchNotes()
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createNote(type: NoteType, text: String, dueAt: Date? = nil, personId: UUID? = nil) async {
        do {
            let newNote = try await supabaseService.createNote(
                personId: personId,
                type: type,
                text: text,
                dueAt: dueAt
            )
            
            // Insert at the beginning since notes are sorted by created_at desc
            notes.insert(newNote, at: 0)
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
        }
    }
    
    func updateNoteStatus(_ note: Note, newStatus: NoteStatus) async {
        do {
            let updatedNote = try await supabaseService.updateNote(
                note.id,
                status: newStatus
            )
            
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = updatedNote
            }
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }
    
    func updateNote(_ note: Note, text: String, dueAt: Date? = nil, personId: UUID? = nil) async {
        do {
            let updatedNote = try await supabaseService.updateNote(
                note.id,
                text: text,
                dueAt: dueAt,
                personId: personId
            )
            
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = updatedNote
            }
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }
    
    func deleteNote(_ note: Note) async {
        do {
            try await supabaseService.deleteNote(note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }
    
    // Helper computed properties
    var openNotes: [Note] {
        notes.filter { $0.type == .note && $0.status == .open }
    }
    
    var openTodos: [Note] {
        notes.filter { $0.type == .todo && $0.status == .open }
    }
    
    var completedItems: [Note] {
        notes.filter { $0.status == .closed }
    }
}