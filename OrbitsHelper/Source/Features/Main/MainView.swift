import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Orbits Helper")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(viewModel.syncStatus)
                .foregroundStyle(.secondary)
                .font(.body)
            
            if viewModel.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Sync Now") {
                    viewModel.triggerSync()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
            
            Text("This app syncs your contacts to Orbits")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}