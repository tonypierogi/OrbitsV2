import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    @Published var syncStatus = "Checking permissions..."
    @Published var isSyncing = false
    @Published var permissionStatus: PermissionsManager.PermissionStatus?
    
    private let syncEngine = SyncEngine()
    
    init() {
        Task {
            await checkPermissions()
        }
    }
    
    func checkPermissions() async {
        permissionStatus = await PermissionsManager.getPermissionStatus()
        if let status = permissionStatus {
            if status.allGranted {
                syncStatus = "Ready to sync."
            } else {
                syncStatus = status.summary
            }
        }
    }
    
    func triggerSync() {
        isSyncing = true
        syncStatus = "Syncing..."
        Task {
            do {
                try await syncEngine.runFullSync()
                syncStatus = "Sync complete at \(Date().formatted())"
            } catch {
                syncStatus = "Sync failed: \(error.localizedDescription)"
            }
            isSyncing = false
        }
    }
}