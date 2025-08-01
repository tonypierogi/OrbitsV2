import SwiftUI

struct NewContactsView: View {
    var body: some View {
        List {
            NavigationLink("New Contact X (Tap Me)") {
                NewContactDetailView()
            }
            NavigationLink("New Contact Y (Tap Me)") {
                NewContactDetailView()
            }
        }
        .navigationTitle("New Connections")
    }
}