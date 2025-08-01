import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                UnreadInboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray.full")
            }

            NavigationStack {
                OrbitsView()
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