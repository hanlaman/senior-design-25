//
//  AuthService.swift
//  caregiverapp
//
//  Protocol defining authentication operations for the app.
//

import Foundation

/// Response from successful authentication
struct AuthUser: Codable {
    let id: String
    let email: String
    let name: String
    let firstName: String?
    let lastName: String?
}

/// Response structure from sign-in/sign-up endpoints
struct AuthResponse: Codable {
    let user: AuthUser?
    let token: String?
}

/// Errors that can occur during authentication
enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case networkError(underlying: Error)
    case invalidResponse
    case notAuthenticated
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .notAuthenticated:
            return "You are not logged in"
        case .serverError(let message):
            return message
        }
    }
}

/// Protocol for authentication services
@MainActor
protocol AuthService: AnyObject {
    /// The currently authenticated user, if any
    var currentUser: AuthUser? { get }

    /// Whether a user is currently authenticated
    var isAuthenticated: Bool { get }

    /// The current auth token
    var authToken: String? { get }

    /// Sign up a new user with email and password
    func signUp(firstName: String, lastName: String, email: String, password: String) async throws -> AuthUser

    /// Sign in an existing user with email and password
    func signIn(email: String, password: String) async throws -> AuthUser

    /// Sign out the current user
    func signOut() async throws

    /// Check if there's a stored session and restore it
    func restoreSession() async -> Bool
}
