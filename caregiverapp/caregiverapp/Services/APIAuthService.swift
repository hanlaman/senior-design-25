//
//  APIAuthService.swift
//  caregiverapp
//
//  Implementation of AuthService that communicates with the backend API.
//

import Foundation

@MainActor
final class APIAuthService: AuthService {
    // MARK: - Configuration

    /// Base URL for the API - change this for production
    private let baseURL: String

    // MARK: - State

    private(set) var currentUser: AuthUser?
    private(set) var authToken: String?

    var isAuthenticated: Bool {
        authToken != nil && currentUser != nil
    }

    // MARK: - Keychain Keys

    private let tokenKeychainKey = "com.caregiverapp.authToken"
    private let userDefaultsKey = "com.caregiverapp.currentUser"

    // MARK: - Initialization

    init(baseURL: String = "http://localhost:3000") {
        self.baseURL = baseURL
    }

    // MARK: - AuthService Implementation

    func signUp(firstName: String, lastName: String, email: String, password: String) async throws -> AuthUser {
        let url = URL(string: "\(baseURL)/api/auth/sign-up/email")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "name": "\(firstName) \(lastName)",
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Extract token from header
        if let token = httpResponse.value(forHTTPHeaderField: "set-auth-token") {
            self.authToken = token
            saveTokenToKeychain(token)
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            if let authResponse = try? decoder.decode(AuthResponse.self, from: data),
               let user = authResponse.user {
                self.currentUser = user
                saveUserToDefaults(user)
                return user
            }
            // Try parsing just the user
            if let user = try? decoder.decode(AuthUser.self, from: data) {
                self.currentUser = user
                saveUserToDefaults(user)
                return user
            }
            // If we got a token but no parseable user, create a minimal user
            if self.authToken != nil {
                let user = AuthUser(id: "", email: email, name: "\(firstName) \(lastName)", firstName: firstName, lastName: lastName)
                self.currentUser = user
                saveUserToDefaults(user)
                return user
            }
            throw AuthError.invalidResponse
        } else if httpResponse.statusCode == 409 {
            throw AuthError.emailAlreadyExists
        } else {
            let errorMessage = parseErrorMessage(from: data) ?? "Sign up failed"
            throw AuthError.serverError(message: errorMessage)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let url = URL(string: "\(baseURL)/api/auth/sign-in/email")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Extract token from header
        if let token = httpResponse.value(forHTTPHeaderField: "set-auth-token") {
            self.authToken = token
            saveTokenToKeychain(token)
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            if let authResponse = try? decoder.decode(AuthResponse.self, from: data),
               let user = authResponse.user {
                self.currentUser = user
                saveUserToDefaults(user)
                return user
            }
            // Try parsing just the user
            if let user = try? decoder.decode(AuthUser.self, from: data) {
                self.currentUser = user
                saveUserToDefaults(user)
                return user
            }
            // If we got a token but no parseable user, create a minimal user
            if self.authToken != nil {
                let user = AuthUser(id: "", email: email, name: email, firstName: nil, lastName: nil)
                self.currentUser = user
                saveUserToDefaults(user)
                return user
            }
            throw AuthError.invalidResponse
        } else if httpResponse.statusCode == 401 {
            throw AuthError.invalidCredentials
        } else {
            let errorMessage = parseErrorMessage(from: data) ?? "Sign in failed"
            throw AuthError.serverError(message: errorMessage)
        }
    }

    func signOut() async throws {
        // Clear local state first
        currentUser = nil
        authToken = nil
        deleteTokenFromKeychain()
        deleteUserFromDefaults()

        // Optionally call the sign-out endpoint
        // This is best-effort, so we don't throw on failure
        let url = URL(string: "\(baseURL)/api/auth/sign-out")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        _ = try? await URLSession.shared.data(for: request)
    }

    func restoreSession() async -> Bool {
        // Try to restore token from keychain
        guard let token = loadTokenFromKeychain() else {
            return false
        }

        self.authToken = token

        // Try to restore user from defaults
        if let user = loadUserFromDefaults() {
            self.currentUser = user
            return true
        }

        // Token exists but no user - could validate with server here
        // For now, just return true if we have a token
        return true
    }

    // MARK: - Network Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(underlying: error)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return nil
    }

    // MARK: - Persistence Helpers

    private func saveTokenToKeychain(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKeychainKey,
            kSecValueData as String: data
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKeychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKeychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func saveUserToDefaults(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadUserFromDefaults() -> AuthUser? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: data) else {
            return nil
        }
        return user
    }

    private func deleteUserFromDefaults() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
