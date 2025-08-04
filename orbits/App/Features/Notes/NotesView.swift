import SwiftUI
import OrbitsKit

struct NotesView: View {
    @StateObject private var viewModel: NotesViewModel
    @State private var showingAddNote = false
    @State private var showCompleted = false
    @State private var editingNote: Note?
    
    init(supabaseService: SupabaseService) {
        self._viewModel = StateObject(wrappedValue: NotesViewModel(supabaseService: supabaseService))
    }
    
    var body: some View {
        List {
            if !viewModel.openNotes.isEmpty {
                Section("Notes") {
                    ForEach(viewModel.openNotes) { note in
                        NavigationLink(destination: NoteDetailView(viewModel: viewModel, note: note)) {
                            NoteRow(note: note, viewModel: viewModel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteNote(note)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingNote = note
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
            
            if !viewModel.openTodos.isEmpty {
                Section("Todos") {
                    ForEach(viewModel.openTodos) { todo in
                        NavigationLink(destination: NoteDetailView(viewModel: viewModel, note: todo)) {
                            TodoRow(todo: todo, viewModel: viewModel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteNote(todo)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingNote = todo
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
            
            if showCompleted && !viewModel.completedItems.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.completedItems) { item in
                        NavigationLink(destination: NoteDetailView(viewModel: viewModel, note: item)) {
                            CompletedItemRow(item: item, viewModel: viewModel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteNote(item)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            
            if viewModel.notes.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Notes Yet",
                    systemImage: "note.text",
                    description: Text("Tap the + button to create your first note")
                )
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddNote = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            
            if !viewModel.completedItems.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation {
                            showCompleted.toggle()
                        }
                    } label: {
                        Text(showCompleted ? "Hide Completed" : "Show Completed")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView(viewModel: viewModel, supabaseService: viewModel.supabaseService)
        }
        .sheet(item: $editingNote) { note in
            EditNoteView(viewModel: viewModel, note: note)
        }
        .task {
            await viewModel.loadNotes()
        }
        .refreshable {
            await viewModel.loadNotes()
        }
        .overlay {
            if viewModel.isLoading && viewModel.notes.isEmpty {
                ProgressView()
            }
        }
    }
}

struct NoteRow: View {
    let note: Note
    let viewModel: NotesViewModel
    
    var noteTitle: String {
        let lines = note.text.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    var noteBody: String? {
        let lines = note.text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }
        let bodyLines = lines.dropFirst()
        let body = bodyLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return body.isEmpty ? nil : body
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(noteTitle)
                .font(.headline)
                .lineLimit(1)
            
            if let body = noteBody {
                Text(body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Text(note.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TodoRow: View {
    let todo: Note
    let viewModel: NotesViewModel
    
    var todoTitle: String {
        let lines = todo.text.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    var todoBody: String? {
        let lines = todo.text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }
        let bodyLines = lines.dropFirst()
        let body = bodyLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return body.isEmpty ? nil : body
    }
    
    var body: some View {
        HStack {
            Button {
                Task {
                    await viewModel.updateNoteStatus(todo, newStatus: .closed)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(todoTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                if let body = todoBody {
                    Text(body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(todo.createdAt, style: .date)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    if let dueAt = todo.dueAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("Due \(dueAt, style: .relative)")
                                .font(.caption)
                        }
                        .foregroundColor(dueAt < Date() ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CompletedItemRow: View {
    let item: Note
    let viewModel: NotesViewModel
    
    var body: some View {
        HStack {
            if item.type == .todo {
                Button {
                    Task {
                        await viewModel.updateNoteStatus(item, newStatus: .open)
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.body)
                    .strikethrough()
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("Completed \(item.updatedAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}