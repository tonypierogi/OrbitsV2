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
                .multilineTextAlignment(.center)
            
            if let permissionStatus = viewModel.permissionStatus,
               !permissionStatus.allGranted,
               let instructions = permissionStatus.instructions {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Required Permissions:")
                        .font(.headline)
                    Text(instructions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Button("Check Permissions") {
                    Task {
                        await viewModel.checkPermissions()
                    }
                }
                .buttonStyle(.bordered)
            }
            
            if viewModel.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else if viewModel.permissionStatus?.contactsAccess == true {
                Button("Sync Now") {
                    viewModel.triggerSync()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("This app syncs your contacts to Orbits")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                if viewModel.permissionStatus?.fullDiskAccess == false {
                    Text("(Message sync requires Full Disk Access)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 400)
    }
}