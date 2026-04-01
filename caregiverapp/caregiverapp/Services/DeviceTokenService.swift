//
//  DeviceTokenService.swift
//  caregiverapp
//
//  Registers the iOS device push token with the backend API.
//

import Foundation
import os

actor DeviceTokenService {
    static let shared = DeviceTokenService()

    private let baseURL: String
    private let patientId: String

    private static let tokenKey = "cachedDeviceToken"

    init(
        baseURL: String = BuildConfiguration.apiBaseURL,
        patientId: String = BuildConfiguration.patientId
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func registerToken(_ tokenData: Data) async {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: Self.tokenKey)
        await sendTokenToServer(tokenString)
    }

    func reregisterCachedToken() async {
        guard let cachedToken = UserDefaults.standard.string(forKey: Self.tokenKey) else {
            return
        }
        await sendTokenToServer(cachedToken)
    }

    private func sendTokenToServer(_ token: String) async {
        guard let url = URL(string: "\(baseURL)/device-tokens") else {
            Logger().error("DeviceTokenService: Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "patientId": patientId,
            "token": token,
            "platform": "ios"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                Logger().info("iOS device token registered successfully")
            } else {
                Logger().warning("iOS device token registration failed with unexpected status")
            }
        } catch {
            Logger().error("Failed to register iOS device token: \(error.localizedDescription)")
        }
    }
}
