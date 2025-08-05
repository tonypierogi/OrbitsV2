import SwiftUI
import OrbitsKit

struct TagPickerView: View {
    @State private var allTags: [Tag]
    let categories: [TagCategory]
    let selectedTags: [Tag]
    let supabaseService: SupabaseService
    let onSave: ([Tag]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedTagIds: Set<UUID>
    @State private var selectedCategoryId: UUID?
    @State private var newTagName = ""
    @State private var isCreatingTag = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(allTags: [Tag], categories: [TagCategory], selectedTags: [Tag], supabaseService: SupabaseService, onSave: @escaping ([Tag]) -> Void, onCancel: @escaping () -> Void) {
        self._allTags = State(initialValue: allTags)
        self.categories = categories
        self.selectedTags = selectedTags
        self.supabaseService = supabaseService
        self.onSave = onSave
        self.onCancel = onCancel
        self._selectedTagIds = State(initialValue: Set(selectedTags.map { $0.id }))
    }
    
    var filteredTags: [Tag] {
        if let categoryId = selectedCategoryId {
            return allTags.filter { $0.categoryId == categoryId }
        } else {
            return allTags
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Create New Tag Section
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("New tag name", text: $newTagName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isCreatingTag)
                        
                        Button(action: createNewTag) {
                            if isCreatingTag {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Text("Create")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(width: 70)
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreatingTag)
                    }
                    
                    if showingError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Category Filter
                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CategoryChip(
                                name: "All",
                                isSelected: selectedCategoryId == nil,
                                action: { selectedCategoryId = nil }
                            )
                            
                            ForEach(categories) { category in
                                CategoryChip(
                                    name: category.name,
                                    isSelected: selectedCategoryId == category.id,
                                    action: { selectedCategoryId = category.id }
                                )
                            }
                            
                            let hasUncategorized = allTags.contains { $0.categoryId == nil }
                            if hasUncategorized {
                                CategoryChip(
                                    name: "Uncategorized",
                                    isSelected: selectedCategoryId == UUID(uuidString: "00000000-0000-0000-0000-000000000000"),
                                    action: { selectedCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemBackground))
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                }
                
                // Tags List
                List {
                    let tagsToShow = selectedCategoryId == UUID(uuidString: "00000000-0000-0000-0000-000000000000") 
                        ? filteredTags.filter { $0.categoryId == nil }
                        : filteredTags
                    
                    ForEach(tagsToShow) { tag in
                        TagSelectionRow(
                            tag: tag,
                            isSelected: selectedTagIds.contains(tag.id),
                            onToggle: { _ in
                                toggleTag(tag)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let selectedTags = allTags.filter { selectedTagIds.contains($0.id) }
                        onSave(selectedTags)
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTagIds.contains(tag.id) {
            selectedTagIds.remove(tag.id)
        } else {
            selectedTagIds.insert(tag.id)
        }
    }
    
    private func createNewTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if tag already exists
        if allTags.contains(where: { $0.label.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A tag with this name already exists"
            showingError = true
            return
        }
        
        isCreatingTag = true
        showingError = false
        
        Task {
            do {
                // Get current user ID from Supabase
                guard let userId = SupabaseManager.shared.client.auth.currentSession?.user.id else {
                    await MainActor.run {
                        errorMessage = "User not authenticated"
                        showingError = true
                        isCreatingTag = false
                    }
                    return
                }
                
                // Create the new tag
                let newTag = Tag(
                    userId: userId,
                    categoryId: selectedCategoryId == UUID(uuidString: "00000000-0000-0000-0000-000000000000") ? nil : selectedCategoryId,
                    label: trimmedName
                )
                
                let createdTag = try await supabaseService.createTag(newTag)
                
                await MainActor.run {
                    // Add to the list and select it
                    allTags.append(createdTag)
                    selectedTagIds.insert(createdTag.id)
                    
                    // Clear the input
                    newTagName = ""
                    isCreatingTag = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create tag: \(error.localizedDescription)"
                    showingError = true
                    isCreatingTag = false
                }
            }
        }
    }
}

struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}