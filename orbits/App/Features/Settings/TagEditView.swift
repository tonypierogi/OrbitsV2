import SwiftUI
import OrbitsKit

struct TagEditView: View {
    @ObservedObject var viewModel: TagManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    let tag: Tag?
    let initialCategoryId: UUID?
    
    @State private var label: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var isSaving = false
    
    init(viewModel: TagManagementViewModel, tag: Tag? = nil, categoryId: UUID? = nil) {
        self.viewModel = viewModel
        self.tag = tag
        self.initialCategoryId = categoryId ?? tag?.categoryId
        _label = State(initialValue: tag?.label ?? "")
        _selectedCategoryId = State(initialValue: categoryId ?? tag?.categoryId)
    }
    
    var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag Label", text: $label)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Tag Information")
                }
                
                Section {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("No Category")
                            .tag(nil as UUID?)
                        
                        ForEach(viewModel.categories) { category in
                            Text(category.name)
                                .tag(category.id as UUID?)
                        }
                    }
                } header: {
                    Text("Category")
                }
            }
            .navigationTitle(tag == nil ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true
        
        if let tag = tag {
            await viewModel.updateTag(tag, label: label, categoryId: selectedCategoryId)
        } else {
            await viewModel.createTag(label: label, categoryId: selectedCategoryId)
        }
        
        isSaving = false
        dismiss()
    }
}