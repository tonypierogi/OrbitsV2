import Foundation
import Supabase

// A simple class to hold our shared Supabase client instance.
public final class SupabaseManager: @unchecked Sendable {
    public static let shared = SupabaseManager() // Singleton pattern
    
    public let client: SupabaseClient
    public let service: SupabaseService
    
    private init() {
        // Configure JSON encoder/decoder for snake_case <-> camelCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Use ISO8601 date formatter with fractional seconds
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            dateFormatter.formatOptions = .withInternetDateTime
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = dateFormatter.string(from: date)
            try container.encode(dateString)
        }
        
        // Initialize the client from your Supabase project details
        self.client = SupabaseClient(
            supabaseURL: URL(string: "https://qvuwrvwjdpriwwdtxfld.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dXdydndqZHByaXd3ZHR4ZmxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQwNzgwNDUsImV4cCI6MjA2OTY1NDA0NX0.76GQXa3LcmiXMRJ23TbqWAGvAzChC2yELr0sDauSqTc",
            options: SupabaseClientOptions(
                db: .init(
                    encoder: encoder,
                    decoder: decoder
                ),
                auth: .init()
            )
        )
        
        // Initialize the service
        self.service = SupabaseService(client: client)
    }
}