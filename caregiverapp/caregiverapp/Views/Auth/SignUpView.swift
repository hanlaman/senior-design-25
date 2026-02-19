//
//  SignUpView.swift
//  caregiverapp
//
//  Sign up view for new users.
//

import SwiftUI

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel
    var onSwitchToLogin: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName, lastName, email, password, confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Sign up to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 20) {
                    // Name row
                    HStack(spacing: 12) {
                        // First name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            TextField("First", text: $viewModel.signUpFirstName)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .textContentType(.givenName)
                                .focused($focusedField, equals: .firstName)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .lastName
                                }
                        }

                        // Last name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            TextField("Last", text: $viewModel.signUpLastName)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .textContentType(.familyName)
                                .focused($focusedField, equals: .lastName)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .email
                                }
                        }
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        TextField("Enter your email", text: $viewModel.signUpEmail)
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

                        SecureField("Create a password", text: $viewModel.signUpPassword)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .confirmPassword
                            }

                        Text("At least 8 characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Confirm password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        SecureField("Confirm your password", text: $viewModel.signUpConfirmPassword)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.go)
                            .onSubmit {
                                Task {
                                    await viewModel.signUp()
                                }
                            }
                    }

                    // Password validation error
                    if let error = viewModel.signUpPasswordError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Server error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)

                // Sign Up Button
                Button {
                    Task {
                        await viewModel.signUp()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .padding()
                    } else {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(viewModel.isSignUpFormValid ? Color.blue : Color.gray.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!viewModel.isSignUpFormValid || viewModel.isLoading)
                .padding(.horizontal, 24)

                // Switch to login
                HStack {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)

                    Button("Sign In") {
                        viewModel.clearError()
                        onSwitchToLogin()
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
    SignUpView(
        viewModel: AuthViewModel(authService: APIAuthService()),
        onSwitchToLogin: {}
    )
}
