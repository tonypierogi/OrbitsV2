import SwiftUI
import OrbitsKit

struct TagPickerView: View {
    let allTags: [Tag]
    let categories: [TagCategory]
    let selectedTags: [Tag]
    let onSave: ([Tag]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedTagIds: Set<UUID>
    @State private var selectedCategoryId: UUID?
    
    init(allTags: [Tag], categories: [TagCategory], selectedTags: [Tag], onSave: @escaping ([Tag]) -> Void, onCancel: @escaping () -> Void) {
        self.allTags = allTags
        self.categories = categories
        self.selectedTags = selectedTags
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