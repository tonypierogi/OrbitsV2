import Foundation
import Supabase

public class SupabaseService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    // MARK: - Person Methods
    
    public func fetchPersons() async throws -> [Person] {
        let persons: [Person] = try await client
            .from("person")
            .select()
            .execute()
            .value
        
        return persons
    }
    
    public func fetchPerson(by id: UUID) async throws -> Person? {
        let person: Person = try await client
            .from("person")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return person
    }
    
    // MARK: - Orbit Methods
    
    public func fetchOrbits() async throws -> [Orbit] {
        let orbits: [Orbit] = try await client
            .from("orbit")
            .select()
            .order("position")
            .execute()
            .value
        
        return orbits
    }
    
    // MARK: - Note Methods
    
    public func fetchNotes(for personId: UUID? = nil) async throws -> [Note] {
        var query = client
            .from("note")
            .select()
        
        if let personId = personId {
            query = query.eq("person_id", value: personId.uuidString)
        }
        
        let notes: [Note] = try await query
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return notes
    }
    
    // MARK: - Tag Methods
    
    public func fetchTags() async throws -> [Tag] {
        let tags: [Tag] = try await client
            .from("tag")
            .select()
            .execute()
            .value
        
        return tags
    }
    
    // MARK: - User Methods
    
    public func getCurrentUser() async throws -> AppUser? {
        guard let userId = client.auth.currentSession?.user.id else {
            return nil
        }
        
        let user: AppUser = try await client
            .from("app_user")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        return user
    }
}