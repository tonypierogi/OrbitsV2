import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Orbits")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            if let authError = viewModel.authError {
                Text(authError.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if viewModel.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 12) {
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
    }
}