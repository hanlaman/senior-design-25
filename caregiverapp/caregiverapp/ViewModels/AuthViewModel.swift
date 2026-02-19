//
//  AuthViewModel.swift
//  caregiverapp
//
//  ViewModel for managing authentication state and operations.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AuthViewModel {
    // MARK: - Dependencies

    private let authService: AuthService

    // MARK: - Published State

    var isAuthenticated: Bool = false
    var currentUser: AuthUser?
    var isLoading: Bool = false
    var errorMessage: String?
    var isCheckingSession: Bool = true

    // Form fields for sign in
    var signInEmail: String = ""
    var signInPassword: String = ""

    // Form fields for sign up
    var signUpFirstName: String = ""
    var signUpLastName: String = ""
    var signUpEmail: String = ""
    var signUpPassword: String = ""
    var signUpConfirmPassword: String = ""

    // MARK: - Validation

    var isSignInFormValid: Bool {
        !signInEmail.isEmpty && !signInPassword.isEmpty && signInPassword.count >= 8
    }

    var isSignUpFormValid: Bool {
        !signUpFirstName.isEmpty &&
        !signUpLastName.isEmpty &&
        !signUpEmail.isEmpty &&
        signUpPassword.count >= 8 &&
        signUpPassword == signUpConfirmPassword
    }

    var signUpPasswordError: String? {
        if signUpPassword.isEmpty {
            return nil
        }
        if signUpPassword.count < 8 {
            return "Password must be at least 8 characters"
        }
        if !signUpConfirmPassword.isEmpty && signUpPassword != signUpConfirmPassword {
            return "Passwords do not match"
        }
        return nil
    }

    // MARK: - Initialization

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Actions

    func checkSession() async {
        isCheckingSession = true
        let restored = await authService.restoreSession()
        if restored {
            isAuthenticated = true
            currentUser = authService.currentUser
        }
        isCheckingSession = false
    }

    func signIn() async {
        guard isSignInFormValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signIn(email: signInEmail, password: signInPassword)
            currentUser = user
            isAuthenticated = true
            clearSignInForm()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }

    func signUp() async {
        guard isSignUpFormValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signUp(
                firstName: signUpFirstName,
                lastName: signUpLastName,
                email: signUpEmail,
                password: signUpPassword
            )
            currentUser = user
            isAuthenticated = true
            clearSignUpForm()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }

    func signOut() async {
        isLoading = true
        do {
            try await authService.signOut()
        } catch {
            // Sign out should still work locally even if server call fails
        }
        currentUser = nil
        isAuthenticated = false
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Helpers

    private func clearSignInForm() {
        signInEmail = ""
        signInPassword = ""
    }

    private func clearSignUpForm() {
        signUpFirstName = ""
        signUpLastName = ""
        signUpEmail = ""
        signUpPassword = ""
        signUpConfirmPassword = ""
    }
}
