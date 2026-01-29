# Troubleshooting Azure Connection Issues

## Current Error: "Bad response from the server" (Error -1011)

This error means the WebSocket handshake is failing. Here's how to debug it:

### 1. Verify Your Azure Configuration

#### Check the API Version
The API version `2025-10-01` might not be correct. To verify:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Speech Service resource
3. Check the API documentation for the correct version

**Common API versions:**
- `2024-10-01-preview` (if using preview features)
- `2024-08-01`
- `2023-12-01-preview`

#### Check the Endpoint Format
The current endpoint format is:
```
wss://{resourceName}.services.ai.azure.com/voice-live/realtime?api-version={version}
```

**Verify this is correct for your service:**
- Azure OpenAI Realtime API uses: `wss://{resource}.openai.azure.com/openai/realtime?api-version={version}&deployment={deployment}`
- Azure Speech Services uses different endpoints for different services

### 2. Test Your API Key with REST API First

Before testing WebSocket, verify your API key works with a simple REST call:

```bash
# Test your API key
curl -X GET "https://{resourceName}.services.ai.azure.com/voice-live/realtime?api-version=2025-10-01" \
  -H "Ocp-Apim-Subscription-Key: {your-api-key}"
```

### 3. Check Required Permissions

Ensure your API key has the correct permissions:
1. Go to Azure Portal → Your Resource
2. Check "Keys and Endpoint"
3. Verify the key is active
4. Check if you need to enable specific features

### 4. Verify the Service Type

Azure has several voice/speech services:

- **Azure OpenAI Service** (with Realtime API)
  - Endpoint: `{resource}.openai.azure.com`
  - Requires deployment name
  - Uses newer models (GPT-4o-realtime-preview)

- **Azure Speech Services**
  - Endpoint: `{region}.stt.speech.microsoft.com` (for STT)
  - Endpoint: `{region}.tts.speech.microsoft.com` (for TTS)
  - Different API structure

- **Azure AI Services** (Multi-service)
  - Endpoint: `{resource}.services.ai.azure.com`
  - May require different authentication

**Action:** Verify which service you actually created in Azure Portal.

### 5. Common Fixes

#### If using Azure OpenAI Realtime API:

Update the endpoint in `BuildConfiguration.swift`:
```swift
// For Azure OpenAI Realtime API
static var websocketURL: URL? {
    let deployment = "gpt-4o-realtime-preview" // or your deployment name
    let urlString = "wss://\(azureResourceName).openai.azure.com/openai/realtime?api-version=\(azureAPIVersion)&deployment=\(deployment)"
    return URL(string: urlString)
}
```

#### If using Azure Speech Services:

You might need a different approach entirely - Speech Services use different endpoints for STT and TTS, not a unified realtime API.

### 6. Enable Diagnostic Logging

Add this to see the full response:

```swift
// In WebSocketManager, after creating the request:
URLSession.shared.configuration.protocolClasses = [CustomWebSocketProtocol.self]
```

### 7. Check Network/Firewall

- Ensure WebSocket connections are allowed
- Check if you're behind a proxy
- Verify SSL/TLS certificates are valid

### 8. Alternative: Use Azure OpenAI Realtime API

If you're trying to build a voice assistant, consider using **Azure OpenAI's Realtime API** instead:

1. Create an Azure OpenAI resource (not Speech Service)
2. Deploy the `gpt-4o-realtime-preview` model
3. Update the endpoint format as shown above

---

## Next Steps

1. **Identify which Azure service you're actually using**
2. **Verify the correct endpoint format for that service**
3. **Update `BuildConfiguration.swift` with the correct endpoint structure**
4. **Test with the corrected configuration**

## Need Help?

Share the following information:
- What type of resource did you create in Azure? (OpenAI / Speech Service / AI Services)
- What's the full resource URL from Azure Portal?
- What deployment/model are you trying to use?
