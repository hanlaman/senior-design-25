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
        // Auth screens bypassed for now — go straight to main content
        ContentView(dataProvider: dataProvider)
            .environment(authViewModel)
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
