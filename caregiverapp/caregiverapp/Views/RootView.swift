//
//  RootView.swift
//  caregiverapp
//
//  Root view that handles authentication state and shows either auth or main content.
//

import SwiftUI

struct RootView: View {
    @Bindable var authViewModel: AuthViewModel
    let dataProvider: PatientDataProvider

    var body: some View {
        Group {
            if authViewModel.isCheckingSession {
                // Show loading screen while checking for existing session
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
            } else if authViewModel.isAuthenticated {
                // Show main app content
                ContentView(dataProvider: dataProvider)
                    .environment(authViewModel)
            } else {
                // Show auth screens
                AuthContainerView(viewModel: authViewModel)
            }
        }
        .task {
            await authViewModel.checkSession()
        }
    }
}

#Preview("Authenticated") {
    RootView(
        authViewModel: {
            let vm = AuthViewModel(authService: APIAuthService())
            vm.isAuthenticated = true
            vm.isCheckingSession = false
            return vm
        }(),
        dataProvider: MockDataService()
    )
}

#Preview("Not Authenticated") {
    RootView(
        authViewModel: {
            let vm = AuthViewModel(authService: APIAuthService())
            vm.isAuthenticated = false
            vm.isCheckingSession = false
            return vm
        }(),
        dataProvider: MockDataService()
    )
}
