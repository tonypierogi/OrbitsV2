import SwiftUI
import OrbitsKit

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NotesViewModel
    
    let note: Note
    @State private var noteText: String
    @State private var selectedDate: Date
    @State private var hasDueDate: Bool
    @State private var selectedPerson: Person?
    @State private var showingPersonPicker = false
    @State private var allPersons: [Person] = []
    
    private let supabaseService: SupabaseService
    
    init(viewModel: NotesViewModel, note: Note) {
        self.viewModel = viewModel
        self.note = note
        self._noteText = State(initialValue: note.text)
        self._selectedDate = State(initialValue: note.dueAt ?? Date().addingTimeInterval(86400))
        self._hasDueDate = State(initialValue: note.dueAt != nil)
        self.supabaseService = viewModel.supabaseService
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Person") {
                    Button {
                        showingPersonPicker = true
                    } label: {
                        HStack {
                            Text("Linked to")
                            Spacer()
                            if let selectedPerson = selectedPerson {
                                Text(selectedPerson.displayName ?? selectedPerson.contactIdentifier)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("None")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if selectedPerson != nil {
                        Button("Clear Selection") {
                            selectedPerson = nil
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Note Content") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 150)
                        .padding(.horizontal, -4)
                }
                
                if note.type == .todo {
                    Section {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        
                        if hasDueDate {
                            DatePicker(
                                "Due Date",
                                selection: $selectedDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }
            }
            .navigationTitle("Edit \(note.type == .note ? "Note" : "Todo")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await loadPersons()
            if let personId = note.personId {
                await loadLinkedPerson(personId)
            }
        }
        .sheet(isPresented: $showingPersonPicker) {
            PersonPickerView(selectedPerson: $selectedPerson, persons: allPersons)
        }
    }
    
    private func loadPersons() async {
        do {
            allPersons = try await supabaseService.fetchPersons()
        } catch {
            print("Failed to load persons: \(error)")
        }
    }
    
    private func loadLinkedPerson(_ personId: UUID) async {
        selectedPerson = allPersons.first { $0.id == personId }
    }
    
    private func saveChanges() async {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let dueDate = (note.type == .todo && hasDueDate) ? selectedDate : nil
        
        await viewModel.updateNote(note, text: trimmedText, dueAt: dueDate, personId: selectedPerson?.id)
        dismiss()
    }
}