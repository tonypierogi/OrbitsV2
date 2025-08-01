import Foundation

public struct Orbit: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let name: String
    public let intervalDays: Int
    public let slackDays: Int
    public let position: Int
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        intervalDays: Int,
        slackDays: Int = 0,
        position: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.intervalDays = intervalDays
        self.slackDays = slackDays
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}