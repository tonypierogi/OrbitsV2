import Foundation
import Contacts

struct PermissionsManager {
    
    // Check if app has contacts access
    static func checkContactsAccess() async -> Bool {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            // Request access
            do {
                let granted = try await store.requestAccess(for: .contacts)
                return granted
            } catch {
                print("Error requesting contacts access: \(error)")
                return false
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // Check if app has Full Disk Access (by trying to access chat.db)
    static func checkFullDiskAccess() -> Bool {
        let chatDbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
        return FileManager.default.isReadableFile(atPath: chatDbPath)
    }
    
    // Get overall permission status
    static func getPermissionStatus() async -> PermissionStatus {
        let contactsAccess = await checkContactsAccess()
        let fullDiskAccess = checkFullDiskAccess()
        
        return PermissionStatus(
            contactsAccess: contactsAccess,
            fullDiskAccess: fullDiskAccess
        )
    }
    
    struct PermissionStatus {
        let contactsAccess: Bool
        let fullDiskAccess: Bool
        
        var allGranted: Bool {
            contactsAccess && fullDiskAccess
        }
        
        var summary: String {
            if allGranted {
                return "All permissions granted"
            }
            
            var missing: [String] = []
            if !contactsAccess {
                missing.append("Contacts")
            }
            if !fullDiskAccess {
                missing.append("Full Disk Access")
            }
            
            return "Missing permissions: \(missing.joined(separator: ", "))"
        }
        
        var instructions: String? {
            if allGranted {
                return nil
            }
            
            var instructions: [String] = []
            
            if !contactsAccess {
                instructions.append("• Grant Contacts access when prompted, or in System Settings > Privacy & Security > Contacts")
            }
            
            if !fullDiskAccess {
                instructions.append("• Grant Full Disk Access in System Settings > Privacy & Security > Full Disk Access")
                instructions.append("  1. Click the + button")
                instructions.append("  2. Add OrbitsHelper to the list")
                instructions.append("  3. Restart the app")
            }
            
            return instructions.joined(separator: "\n")
        }
    }
}