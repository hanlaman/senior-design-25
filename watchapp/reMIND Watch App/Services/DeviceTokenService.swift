//
//  DeviceTokenService.swift
//  reMIND Watch App
//
//  Registers the device push token with the backend API.
//

import Foundation
import os

actor DeviceTokenService {
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

        // Cache token for re-registration on restart
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
            AppLogger.general.error("DeviceTokenService: Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "patientId": patientId,
            "token": token,
            "platform": "watchos"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            try await RetryHelper.withRetry {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    AppLogger.general.info("Device token registered successfully")
                } else {
                    AppLogger.general.warning("Device token registration failed with unexpected status")
                }
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to register device token after retries")
        }
    }
}
