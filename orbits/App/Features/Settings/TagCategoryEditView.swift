import SwiftUI
import OrbitsKit

struct TagCategoryEditView: View {
    @ObservedObject var viewModel: TagManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    let category: TagCategory?
    @State private var name: String = ""
    @State private var isSaving = false
    
    init(viewModel: TagManagementViewModel, category: TagCategory? = nil) {
        self.viewModel = viewModel
        self.category = category
        _name = State(initialValue: category?.name ?? "")
    }
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Category Information")
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
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
        
        if let category = category {
            await viewModel.updateCategory(category, name: name)
        } else {
            await viewModel.createCategory(name: name)
        }
        
        isSaving = false
        dismiss()
    }
}