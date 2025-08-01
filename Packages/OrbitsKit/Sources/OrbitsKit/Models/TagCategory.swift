import Foundation

public struct TagCategory: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let name: String
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
    }
}