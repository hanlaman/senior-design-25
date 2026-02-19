#!/bin/bash

# Script to generate BuildConfiguration.swift from build settings
# This runs as a build phase in Xcode

set -e

OUTPUT_FILE="${SRCROOT}/reMIND Watch App/Configuration/BuildConfiguration.swift"

# Create directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate Swift file with build settings
cat > "$OUTPUT_FILE" <<EOF
//
//  BuildConfiguration.swift
//  reMIND Watch App
//
//  Auto-generated from build settings - DO NOT EDIT
//  Generated on $(date)
//

import Foundation

enum BuildConfiguration {
    static let azureAPIKey = "${AZURE_API_KEY}"
    static let azureResourceName = "${AZURE_RESOURCE_NAME}"
    static let azureAPIVersion = "${AZURE_API_VERSION}"

    static var websocketURL: URL? {
        let urlString = "wss://\(azureResourceName).services.ai.azure.com/voice-live/realtime?api-version=\(azureAPIVersion)"
        return URL(string: urlString)
    }

    static var isConfigured: Bool {
        !azureAPIKey.isEmpty &&
        azureAPIKey != "YOUR_API_KEY_HERE" &&
        !azureResourceName.isEmpty &&
        azureResourceName != "YOUR_RESOURCE_NAME_HERE"
    }
}
EOF

echo "Generated BuildConfiguration.swift"
