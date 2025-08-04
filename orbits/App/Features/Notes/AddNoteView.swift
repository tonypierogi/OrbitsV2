import SwiftUI
import OrbitsKit

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NotesViewModel
    
    @State private var noteText = ""
    @State private var selectedType: NoteType = .note
    @State private var selectedDate: Date = Date().addingTimeInterval(86400) // Tomorrow
    @State private var hasDueDate = false
    @State private var selectedPerson: Person?
    @State private var showingPersonPicker = false
    @State private var allPersons: [Person] = []
    
    let person: Person?
    private let supabaseService: SupabaseService
    
    init(viewModel: NotesViewModel, person: Person? = nil, supabaseService: SupabaseService? = nil) {
        self.viewModel = viewModel
        self.person = person
        self.supabaseService = supabaseService ?? SupabaseService(client: SupabaseManager.shared.client)
        self._selectedPerson = State(initialValue: person)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        Text("Note").tag(NoteType.note)
                        Text("Todo").tag(NoteType.todo)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedType) { _, newValue in
                        if newValue == .note {
                            hasDueDate = false
                        }
                    }
                }
                
                Section("Note Content") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 150)
                        .padding(.horizontal, -4)
                }
                
                if selectedType == .todo {
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
                
                Section {
                    Button {
                        showingPersonPicker = true
                    } label: {
                        HStack {
                            Text("Person")
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
            }
            .navigationTitle("New \(selectedType == .note ? "Note" : "Todo")")
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
                            await saveNote()
                        }
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await loadPersons()
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
    
    private func saveNote() async {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let dueDate = (selectedType == .todo && hasDueDate) ? selectedDate : nil
        
        await viewModel.createNote(
            type: selectedType,
            text: trimmedText,
            dueAt: dueDate,
            personId: selectedPerson?.id
        )
        
        dismiss()
    }
}