import SwiftUI
import OrbitsKit

struct SettingsView: View {
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: TagManagementView(supabaseService: supabaseService)) {
                    Label("Tags", systemImage: "tag")
                }
            } header: {
                Text("Organization")
            }
            
            Section {
                Text("Sync Settings")
                Text("Privacy")
                Text("Account")
            } header: {
                Text("General")
            }
        }
        .navigationTitle("Settings")
    }
}