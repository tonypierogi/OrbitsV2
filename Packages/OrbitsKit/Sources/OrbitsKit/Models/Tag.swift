import Foundation

public struct Tag: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let categoryId: UUID?
    public let label: String
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        categoryId: UUID? = nil,
        label: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.categoryId = categoryId
        self.label = label
        self.createdAt = createdAt
    }
}