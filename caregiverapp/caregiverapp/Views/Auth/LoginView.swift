//
//  LoginView.swift
//  caregiverapp
//
//  Sign in view for existing users.
//

import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    var onSwitchToSignUp: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 20) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        TextField("Enter your email", text: $viewModel.signInEmail)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .password
                            }
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        SecureField("Enter your password", text: $viewModel.signInPassword)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                Task {
                                    await viewModel.signIn()
                                }
                            }
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)

                // Sign In Button
                Button {
                    Task {
                        await viewModel.signIn()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .padding()
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(viewModel.isSignInFormValid ? Color.blue : Color.gray.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!viewModel.isSignInFormValid || viewModel.isLoading)
                .padding(.horizontal, 24)

                // Switch to sign up
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)

                    Button("Sign Up") {
                        viewModel.clearError()
                        onSwitchToSignUp()
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)

                Spacer()
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

#Preview {
    LoginView(
        viewModel: AuthViewModel(authService: APIAuthService()),
        onSwitchToSignUp: {}
    )
}
