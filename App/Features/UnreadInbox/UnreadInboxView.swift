import SwiftUI

struct UnreadInboxView: View {
    var body: some View {
        List {
            NavigationLink("Unread Contact 1 (Tap Me)") {
                ContactDetailView()
            }
            NavigationLink("Unread Contact 2 (Tap Me)") {
                ContactDetailView()
            }
        }
        .navigationTitle("Inbox")
    }
}