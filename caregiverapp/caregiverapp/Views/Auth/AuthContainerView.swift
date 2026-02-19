//
//  AuthContainerView.swift
//  caregiverapp
//
//  Container view that manages switching between login and sign up views.
//

import SwiftUI

struct AuthContainerView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var showSignUp = false

    var body: some View {
        Group {
            if showSignUp {
                SignUpView(
                    viewModel: viewModel,
                    onSwitchToLogin: {
                        withAnimation {
                            showSignUp = false
                        }
                    }
                )
                .transition(.move(edge: .trailing))
            } else {
                LoginView(
                    viewModel: viewModel,
                    onSwitchToSignUp: {
                        withAnimation {
                            showSignUp = true
                        }
                    }
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut, value: showSignUp)
    }
}

#Preview {
    AuthContainerView(
        viewModel: AuthViewModel(authService: APIAuthService())
    )
}
