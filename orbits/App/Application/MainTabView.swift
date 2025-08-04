import SwiftUI
import OrbitsKit

struct MainTabView: View {
    private let supabaseService = SupabaseService(client: SupabaseManager.shared.client)
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                UnreadInboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray.full")
            }
            .tag(0)

            NavigationStack {
                OrbitsView(supabaseService: supabaseService)
            }
            .tabItem {
                Label("Orbits", systemImage: "rotate.3d")
            }
            .tag(1)

            NavigationStack {
                NewContactsView()
            }
            .tabItem {
                Label("New", systemImage: "sparkles")
            }
            .tag(2)

            NavigationStack {
                NotesView(supabaseService: supabaseService)
            }
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
        }
    }
}