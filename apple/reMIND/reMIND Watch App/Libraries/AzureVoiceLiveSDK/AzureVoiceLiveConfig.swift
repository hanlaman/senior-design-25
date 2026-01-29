//
//  AzureVoiceLiveConfig.swift
//  reMIND
//
//  Configuration structure for Azure Voice Live SDK
//

import Foundation

public struct AzureVoiceLiveConfig {
    public let apiKey: String
    public let resourceName: String
    public let apiVersion: String
    public let model: String

    public var websocketURL: URL? {
        let urlString = "wss://\(resourceName).services.ai.azure.com/voice-live/realtime?api-version=\(apiVersion)&model=\(model)"
        return URL(string: urlString)
    }

    public var isValid: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" &&
        !resourceName.isEmpty && resourceName != "YOUR_RESOURCE_NAME_HERE" &&
        websocketURL != nil
    }

    public init(apiKey: String, resourceName: String, apiVersion: String, model: String) {
        self.apiKey = apiKey
        self.resourceName = resourceName
        self.apiVersion = apiVersion
        self.model = model
    }

    public func validate() -> String? {
        if apiKey.isEmpty || apiKey == "YOUR_API_KEY_HERE" {
            return "API key not configured"
        }
        if resourceName.isEmpty || resourceName == "YOUR_RESOURCE_NAME_HERE" {
            return "Resource name not configured"
        }
        if websocketURL == nil {
            return "Invalid resource name"
        }
        return nil
    }
}
