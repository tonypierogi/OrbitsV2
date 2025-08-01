import Foundation
import Contacts

// This service is responsible for fetching contacts from the user's local Contacts database.
// IMPORTANT: This requires getting permission from the user.
struct LocalContactsProvider {
    private let store = CNContactStore()

    func fetchAllContacts() throws -> [CNContact] {
        // Define the specific contact properties (keys) we want to fetch.
        let keysToFetch = [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactImageDataAvailableKey,
            CNContactImageDataKey
        ] as [CNKeyDescriptor]
        
        var allContainers: [CNContainer] = []
        allContainers = try store.containers(matching: nil)
        
        var results: [CNContact] = []
        for container in allContainers {
            let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            let containerResults = try store.unifiedContacts(matching: fetchPredicate, keysToFetch: keysToFetch)
            results.append(contentsOf: containerResults)
        }
        return results
    }
}