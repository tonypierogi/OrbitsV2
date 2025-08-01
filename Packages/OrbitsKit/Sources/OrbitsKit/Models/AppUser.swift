import Foundation

public struct AppUser: Codable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String?
    public let createdAt: Date
    
    public init(id: UUID, displayName: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }
}