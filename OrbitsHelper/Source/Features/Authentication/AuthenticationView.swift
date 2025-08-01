import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Orbits Helper")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)

            if let authError = viewModel.authError {
                Text(authError.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 12) {
                    Button("Sign In") {
                        Task { await viewModel.signIn() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Sign Up") {
                        Task { await viewModel.signUp() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(width: 350, height: 300)
    }
}