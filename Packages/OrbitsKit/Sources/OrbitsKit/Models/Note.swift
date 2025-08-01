import Foundation

public enum NoteType: String, Codable, Sendable {
    case note = "note"
    case todo = "todo"
}

public enum NoteStatus: String, Codable, Sendable {
    case open = "open"
    case closed = "closed"
}

public struct Note: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let personId: UUID?
    public let type: NoteType
    public let text: String
    public let dueAt: Date?
    public let status: NoteStatus
    public let autoCreated: Bool
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        personId: UUID? = nil,
        type: NoteType,
        text: String,
        dueAt: Date? = nil,
        status: NoteStatus = .open,
        autoCreated: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.personId = personId
        self.type = type
        self.text = text
        self.dueAt = dueAt
        self.status = status
        self.autoCreated = autoCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}