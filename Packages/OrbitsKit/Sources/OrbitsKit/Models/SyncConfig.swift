import Foundation

public struct SyncConfig: Codable, Sendable {
    public let userId: UUID
    public let cadenceMinutes: Int
    public let lastRunAt: Date?
    public let lastContactScanAt: Date?
    public let lastUnreadScanAt: Date?
    public let updatedAt: Date
    
    public init(
        userId: UUID,
        cadenceMinutes: Int = 60,
        lastRunAt: Date? = nil,
        lastContactScanAt: Date? = nil,
        lastUnreadScanAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.cadenceMinutes = cadenceMinutes
        self.lastRunAt = lastRunAt
        self.lastContactScanAt = lastContactScanAt
        self.lastUnreadScanAt = lastUnreadScanAt
        self.updatedAt = updatedAt
    }
}