import SwiftUI
import OrbitsKit

struct MainTabView: View {
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    
    var body: some View {
        TabView {
            NavigationStack {
                UnreadInboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray.full")
            }

            NavigationStack {
                OrbitsView(supabaseService: supabaseService)
            }
            .tabItem {
                Label("Orbits", systemImage: "rotate.3d")
            }

            NavigationStack {
                NewContactsView()
            }
            .tabItem {
                Label("New", systemImage: "sparkles")
            }

            NavigationStack {
                NotesView()
            }
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}