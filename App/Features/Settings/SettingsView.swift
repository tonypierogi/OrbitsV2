import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Text("Sync Settings")
            Text("Privacy")
            Text("Account")
        }
        .navigationTitle("Settings")
    }
}