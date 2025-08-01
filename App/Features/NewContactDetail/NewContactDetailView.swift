import SwiftUI

struct NewContactDetailView: View {
    var body: some View {
        VStack {
            Text("New Contact Detail Placeholder")
                .font(.title)
            Text("The special 'How We Met' UI will go here.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("New Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
}