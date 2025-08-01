import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    @Published var syncStatus = "Ready to sync."
    @Published var isSyncing = false
    private let syncEngine = SyncEngine()
    
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