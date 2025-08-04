import SwiftUI
import OrbitsKit
import Supabase

@MainActor
class TagManagementViewModel: ObservableObject {
    @Published var categories: [TagCategory] = []
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedCategory: TagCategory?
    
    private let supabaseService: SupabaseService
    private let supabaseClient = SupabaseManager.shared.client
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    func loadData() async {
        isLoading = true
        error = nil
        
        do {
            async let fetchedCategories = supabaseService.fetchTagCategories()
            async let fetchedTags = supabaseService.fetchTags()
            
            let (cats, tgs) = try await (fetchedCategories, fetchedTags)
            categories = cats
            tags = tgs
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createCategory(name: String) async {
        guard let userId = supabaseClient.auth.currentSession?.user.id else { return }
        
        let category = TagCategory(userId: userId, name: name)
        
        do {
            let newCategory = try await supabaseService.createTagCategory(category)
            categories.append(newCategory)
        } catch {
            self.error = error
        }
    }
    
    func updateCategory(_ category: TagCategory, name: String) async {
        let updatedCategory = TagCategory(
            id: category.id,
            userId: category.userId,
            name: name,
            createdAt: category.createdAt
        )
        
        do {
            let result = try await supabaseService.updateTagCategory(updatedCategory)
            if let index = categories.firstIndex(where: { $0.id == category.id }) {
                categories[index] = result
            }
        } catch {
            self.error = error
        }
    }
    
    func deleteCategory(_ category: TagCategory) async {
        do {
            try await supabaseService.deleteTagCategory(category.id)
            categories.removeAll { $0.id == category.id }
            tags.removeAll { $0.categoryId == category.id }
        } catch {
            self.error = error
        }
    }
    
    func createTag(label: String, categoryId: UUID?) async {
        guard let userId = supabaseClient.auth.currentSession?.user.id else { return }
        
        let tag = Tag(userId: userId, categoryId: categoryId, label: label)
        
        do {
            let newTag = try await supabaseService.createTag(tag)
            tags.append(newTag)
        } catch {
            self.error = error
        }
    }
    
    func updateTag(_ tag: Tag, label: String, categoryId: UUID?) async {
        let updatedTag = Tag(
            id: tag.id,
            userId: tag.userId,
            categoryId: categoryId,
            label: label,
            createdAt: tag.createdAt
        )
        
        do {
            let result = try await supabaseService.updateTag(updatedTag)
            if let index = tags.firstIndex(where: { $0.id == tag.id }) {
                tags[index] = result
            }
        } catch {
            self.error = error
        }
    }
    
    func deleteTag(_ tag: Tag) async {
        do {
            try await supabaseService.deleteTag(tag.id)
            tags.removeAll { $0.id == tag.id }
        } catch {
            self.error = error
        }
    }
    
    func tagsForCategory(_ categoryId: UUID?) -> [Tag] {
        tags.filter { $0.categoryId == categoryId }
    }
}