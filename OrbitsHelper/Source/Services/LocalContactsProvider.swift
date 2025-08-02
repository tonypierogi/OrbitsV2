import Foundation
import Contacts

// This service is responsible for fetching contacts from the user's local Contacts database.
// IMPORTANT: This requires getting permission from the user.
struct LocalContactsProvider {
    private let store = CNContactStore()
    
    struct ContactWithHandles {
        let contact: CNContact
        let phoneNumbers: [String]
        let emailAddresses: [String]
        
        var allHandles: [String] {
            phoneNumbers + emailAddresses
        }
    }

    func fetchAllContacts() async throws -> [CNContact] {
        // Define the specific contact properties (keys) we want to fetch.
        let keysToFetch = [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactImageDataAvailableKey,
            CNContactImageDataKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ] as [CNKeyDescriptor]
        
        // Run contacts fetching on a background queue to avoid QoS warnings
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .background) {
                do {
                    var allContainers: [CNContainer] = []
                    allContainers = try store.containers(matching: nil)
                    
                    var results: [CNContact] = []
                    for container in allContainers {
                        let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                        let containerResults = try store.unifiedContacts(matching: fetchPredicate, keysToFetch: keysToFetch)
                        results.append(contentsOf: containerResults)
                    }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchAllContactsWithHandles() async throws -> [ContactWithHandles] {
        let contacts = try await fetchAllContacts()
        
        return contacts.map { contact in
            // Extract phone numbers
            let phoneNumbers = contact.phoneNumbers.map { phoneNumber in
                phoneNumber.value.stringValue
            }
            
            // Extract email addresses
            let emailAddresses = contact.emailAddresses.map { email in
                email.value as String
            }
            
            return ContactWithHandles(
                contact: contact,
                phoneNumbers: phoneNumbers,
                emailAddresses: emailAddresses
            )
        }
    }
    
    // Create a mapping of handles (phone/email) to contacts for quick lookup
    func createHandleToContactMapping() async throws -> [String: CNContact] {
        let contactsWithHandles = try await fetchAllContactsWithHandles()
        var mapping: [String: CNContact] = [:]
        
        for contactWithHandles in contactsWithHandles {
            // Map normalized phone numbers
            for phoneNumber in contactWithHandles.phoneNumbers {
                let normalized = normalizePhoneNumber(phoneNumber)
                mapping[normalized] = contactWithHandles.contact
                // Also map the original format
                mapping[phoneNumber] = contactWithHandles.contact
            }
            
            // Map email addresses (lowercase for case-insensitive matching)
            for email in contactWithHandles.emailAddresses {
                mapping[email.lowercased()] = contactWithHandles.contact
                mapping[email] = contactWithHandles.contact
            }
        }
        
        return mapping
    }
    
    // Normalize phone number by removing all non-numeric characters
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // If it's a 10-digit number, add the US country code
        if digits.count == 10 {
            return "1" + digits
        }
        
        return digits
    }
}