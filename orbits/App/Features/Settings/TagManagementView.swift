import SwiftUI
import OrbitsKit

struct TagManagementView: View {
    @StateObject private var viewModel: TagManagementViewModel
    @State private var showingAddCategory = false
    @State private var showingAddTag = false
    @State private var selectedCategory: TagCategory?
    
    init(supabaseService: SupabaseService) {
        _viewModel = StateObject(wrappedValue: TagManagementViewModel(supabaseService: supabaseService))
    }
    
    var body: some View {
        List {
            Section {
                ForEach(viewModel.categories) { category in
                    NavigationLink(destination: TagCategoryDetailView(
                        category: category,
                        viewModel: viewModel
                    )) {
                        HStack {
                            Text(category.name)
                            Spacer()
                            Text("\(viewModel.tagsForCategory(category.id).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let category = viewModel.categories[index]
                        Task {
                            await viewModel.deleteCategory(category)
                        }
                    }
                }
                
                Button(action: { showingAddCategory = true }) {
                    Label("Add Category", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Categories")
            }
            
            Section {
                ForEach(viewModel.tagsForCategory(nil)) { tag in
                    TagRowView(tag: tag, viewModel: viewModel)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let tags = viewModel.tagsForCategory(nil)
                        let tag = tags[index]
                        Task {
                            await viewModel.deleteTag(tag)
                        }
                    }
                }
                
                Button(action: { 
                    selectedCategory = nil
                    showingAddTag = true 
                }) {
                    Label("Add Tag", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Uncategorized Tags")
            }
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showingAddCategory) {
            TagCategoryEditView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddTag) {
            TagEditView(viewModel: viewModel, categoryId: selectedCategory?.id)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

struct TagRowView: View {
    let tag: Tag
    let viewModel: TagManagementViewModel
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            Text(tag.label)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            TagEditView(viewModel: viewModel, tag: tag, categoryId: tag.categoryId)
        }
    }
}