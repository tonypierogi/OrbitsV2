import SwiftUI
import OrbitsKit

struct TagCategoryDetailView: View {
    let category: TagCategory
    @ObservedObject var viewModel: TagManagementViewModel
    @State private var showingEditCategory = false
    @State private var showingAddTag = false
    
    var categoryTags: [Tag] {
        viewModel.tagsForCategory(category.id)
    }
    
    var body: some View {
        List {
            Section {
                ForEach(categoryTags) { tag in
                    TagRowView(tag: tag, viewModel: viewModel)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let tag = categoryTags[index]
                        Task {
                            await viewModel.deleteTag(tag)
                        }
                    }
                }
                
                Button(action: { showingAddTag = true }) {
                    Label("Add Tag", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Tags in \(category.name)")
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditCategory = true
                }
            }
        }
        .sheet(isPresented: $showingEditCategory) {
            TagCategoryEditView(viewModel: viewModel, category: category)
        }
        .sheet(isPresented: $showingAddTag) {
            TagEditView(viewModel: viewModel, categoryId: category.id)
        }
    }
}