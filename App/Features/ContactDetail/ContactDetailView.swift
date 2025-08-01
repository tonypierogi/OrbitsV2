import SwiftUI

struct ContactDetailView: View {
    var body: some View {
        VStack {
            Text("Contact Detail Placeholder")
                .font(.title)
            Text("Notes, tags, and activity will go here.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Contact Name")
        .navigationBarTitleDisplayMode(.inline)
    }
}