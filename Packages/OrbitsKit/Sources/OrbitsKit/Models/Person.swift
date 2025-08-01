import Foundation

public struct Person: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let contactIdentifier: String
    public let displayName: String?
    public let photoHash: String?
    public let photoAvailable: Bool
    public let orbitId: UUID?
    public let unreadCount: Int
    public let lastMessageAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        contactIdentifier: String,
        displayName: String? = nil,
        photoHash: String? = nil,
        photoAvailable: Bool = false,
        orbitId: UUID? = nil,
        unreadCount: Int = 0,
        lastMessageAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.contactIdentifier = contactIdentifier
        self.displayName = displayName
        self.photoHash = photoHash
        self.photoAvailable = photoAvailable
        self.orbitId = orbitId
        self.unreadCount = unreadCount
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}