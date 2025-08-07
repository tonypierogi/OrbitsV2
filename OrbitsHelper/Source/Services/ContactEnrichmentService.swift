import Foundation
import Contacts
import CryptoKit

struct ContactEnrichmentService {
    
    // Normalize a phone number for consistent matching
    static func normalizePhoneNumber(_ phoneNumber: String) -> String {
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Standardize on 10-digit format (remove country code if present)
        if digits.count == 11 && digits.hasPrefix("1") {
            return String(digits.dropFirst())
        }
        
        return digits
    }
    
    // Normalize an email address for consistent matching
    static func normalizeEmail(_ email: String) -> String {
        return email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Normalize any handle (phone or email)
    static func normalizeHandle(_ handle: String) -> String {
        // Check if it looks like an email
        if handle.contains("@") {
            return normalizeEmail(handle)
        } else {
            return normalizePhoneNumber(handle)
        }
    }
    
    // Generate a hash for contact photo data
    static func generatePhotoHash(from imageData: Data?) -> String? {
        guard let imageData = imageData else { return nil }
        
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Convert iMessage handle format to standard format
    static func convertIMessageHandle(_ handle: String) -> String {
        // Remove country code prefix if present (e.g., "+1" for US)
        var normalized = handle
        
        // Remove "+" prefix if present
        if normalized.hasPrefix("+") {
            normalized.removeFirst()
        }
        
        // For phone numbers, normalize
        if !normalized.contains("@") {
            normalized = normalizePhoneNumber(normalized)
        } else {
            // For emails, just normalize case
            normalized = normalizeEmail(normalized)
        }
        
        return normalized
    }
    
    // Build display name from CNContact
    static func buildDisplayName(from contact: CNContact) -> String {
        var components: [String] = []
        
        if !contact.givenName.isEmpty {
            components.append(contact.givenName)
        }
        
        if !contact.familyName.isEmpty {
            components.append(contact.familyName)
        }
        
        // If no name components, return organization name or a default
        if components.isEmpty {
            if !contact.organizationName.isEmpty {
                return contact.organizationName
            } else {
                return "Unknown Contact"
            }
        }
        
        return components.joined(separator: " ")
    }
    
    // Find the best contact identifier (prefer phone number over email)
    static func findBestContactIdentifier(from contact: CNContact) -> String? {
        // First try to get a phone number
        if let firstPhone = contact.phoneNumbers.first {
            return normalizePhoneNumber(firstPhone.value.stringValue)
        }
        
        // Then try email
        if let firstEmail = contact.emailAddresses.first {
            return normalizeEmail(firstEmail.value as String)
        }
        
        // No identifiers found
        return nil
    }
    
    // Get the primary phone number from contact
    static func getPrimaryPhoneNumber(from contact: CNContact) -> String? {
        guard let firstPhone = contact.phoneNumbers.first else { return nil }
        return normalizePhoneNumber(firstPhone.value.stringValue)
    }
    
    // Get the primary email address from contact
    static func getPrimaryEmailAddress(from contact: CNContact) -> String? {
        guard let firstEmail = contact.emailAddresses.first else { return nil }
        return normalizeEmail(firstEmail.value as String)
    }
}