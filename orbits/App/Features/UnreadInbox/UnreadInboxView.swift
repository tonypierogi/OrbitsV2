import SwiftUI
import OrbitsKit

struct UnreadInboxView: View {
    @StateObject private var viewModel = UnreadInboxViewModel()
    
    var body: some View {
        List {
            if viewModel.unreadContacts.isEmpty {
                ContentUnavailableView(
                    "No Unread Messages", 
                    systemImage: "tray",
                    description: Text("Messages from your contacts will appear here")
                )
            } else {
                ForEach(viewModel.unreadContacts) { person in
                    NavigationLink(destination: ContactDetailView(
                        person: person,
                        supabaseService: viewModel.supabaseService
                    )) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(person.displayName ?? person.contactIdentifier)
                                    .font(.headline)
                                Text("\(person.unreadCount) unread")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Inbox")
        .task {
            await viewModel.loadUnreadContacts()
        }
    }
}