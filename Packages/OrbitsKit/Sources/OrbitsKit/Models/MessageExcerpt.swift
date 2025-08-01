import Foundation

public enum ExcerptPurpose: String, Codable, Sendable {
    case newContact = "new_contact"
    case unread = "unread"
}

public struct MessageExcerpt: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let personId: UUID
    public let purpose: ExcerptPurpose
    public let content: String
    public let createdAt: Date
    public let autoDeleteAt: Date
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        personId: UUID,
        purpose: ExcerptPurpose,
        content: String,
        createdAt: Date = Date(),
        autoDeleteAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.personId = personId
        self.purpose = purpose
        self.content = content
        self.createdAt = createdAt
        self.autoDeleteAt = autoDeleteAt
    }
}