//
//  AzureConfig.swift
//  reMIND Watch App
//
//  Build-time configuration for Azure Voice Live API
//

import Foundation
import Combine

/// Build-time configuration for Azure Voice Live API
/// Credentials are set at build time via Xcode build settings
struct AzureConfig {
    /// Azure API key (set via AZURE_API_KEY build setting)
    let apiKey: String

    /// Azure resource name (set via AZURE_RESOURCE_NAME build setting)
    let resourceName: String

    /// API version (set via AZURE_API_VERSION build setting)
    let apiVersion: String

    /// WebSocket endpoint URL (from BuildConfiguration)
    var websocketURL: URL? {
        BuildConfiguration.websocketURL
    }

    /// Check if configuration is valid
    var isValid: Bool {
        !apiKey.isEmpty &&
        apiKey != "YOUR_API_KEY_HERE" &&
        !resourceName.isEmpty &&
        resourceName != "YOUR_RESOURCE_NAME_HERE" &&
        websocketURL != nil
    }

    /// Shared instance using build-time configuration
    static let shared = AzureConfig(
        apiKey: BuildConfiguration.azureAPIKey,
        resourceName: BuildConfiguration.azureResourceName,
        apiVersion: BuildConfiguration.azureAPIVersion
    )

    /// Validate and return error message if invalid
    func validate() -> String? {
        if apiKey.isEmpty || apiKey == "YOUR_API_KEY_HERE" {
            return "API key not configured. Set AZURE_API_KEY in Config.xcconfig"
        }
        if resourceName.isEmpty || resourceName == "YOUR_RESOURCE_NAME_HERE" {
            return "Resource name not configured. Set AZURE_RESOURCE_NAME in Config.xcconfig"
        }
        if websocketURL == nil {
            return "Invalid resource name"
        }
        return nil
    }
}
