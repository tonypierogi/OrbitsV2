import Foundation

public struct PersonTag: Codable, Sendable {
    public let personId: UUID
    public let tagId: UUID
    
    public init(personId: UUID, tagId: UUID) {
        self.personId = personId
        self.tagId = tagId
    }
}