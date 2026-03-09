//
//  FunctionCallCoordinator.swift
//  reMIND Watch App
//
//  Coordinates function call lifecycle (receive request → execute → send result)
//

import Foundation
import os

// MARK: - FunctionCallCoordinatorDelegate

/// Delegate protocol for function call coordinator events
@MainActor
public protocol FunctionCallCoordinatorDelegate: AnyObject {
    /// Called when a function execution completes
    /// - Parameters:
    ///   - coordinator: The coordinator instance
    ///   - callId: The call ID of the completed function
    func functionCallCoordinator(_ coordinator: FunctionCallCoordinator, didCompleteFunctionCall callId: String)
}

// MARK: - FunctionCallCoordinator

/// Coordinates the function call lifecycle for Azure Voice Live
@MainActor
public class FunctionCallCoordinator {
    /// Delegate for function call events
    public weak var delegate: FunctionCallCoordinatorDelegate?

    private let toolRegistry: ToolRegistry
    private let azureService: any AzureServiceProtocol

    /// Track in-flight function calls by call ID
    private var activeCalls: [String: Task<Void, Never>] = [:]

    /// Initialize coordinator
    /// - Parameters:
    ///   - toolRegistry: Registry of available tools
    ///   - azureService: Azure Voice Live connection service
    public init(toolRegistry: ToolRegistry, azureService: any AzureServiceProtocol) {
        self.toolRegistry = toolRegistry
        self.azureService = azureService
    }

    /// Handle incoming function call request from Azure
    /// - Parameter item: Function call item from conversation
    public func handleFunctionCall(_ item: RealtimeConversationFunctionCallItem) async {
        let callId = item.callId
        let functionName = item.name
        let arguments = item.arguments

        AppLogger.azure.info("🔧 Executing function: \(functionName) (call_id: \(callId))")

        // Cancel any existing task for this call ID
        activeCalls[callId]?.cancel()

        // Create task to execute function
        let task = Task { @MainActor in
            do {
                // Find tool in registry
                guard let tool = toolRegistry.findTool(byName: functionName) else {
                    throw ToolError.toolNotFound(functionName)
                }

                // Execute the function
                let output = try await tool.execute(arguments: arguments)

                AppLogger.azure.info("✅ Function \(functionName) completed successfully")

                // Send result back to Azure
                try await sendFunctionResult(callId: callId, output: output)

                // Trigger new response to incorporate the result
                try await azureService.response.create(options: nil)

                // Notify delegate
                delegate?.functionCallCoordinator(self, didCompleteFunctionCall: callId)

            } catch let error as ToolError {
                AppLogger.logError(error, category: AppLogger.azure, context: "Function execution failed")

                // Send error back to Azure
                let errorOutput = "{\"error\": \"\(error.localizedDescription)\"}"
                try? await sendFunctionResult(callId: callId, output: errorOutput)

            } catch {
                AppLogger.logError(error, category: AppLogger.azure, context: "Unexpected function execution error")

                // Send error back to Azure
                let errorOutput = "{\"error\": \"\(error.localizedDescription)\"}"
                try? await sendFunctionResult(callId: callId, output: errorOutput)
            }

            // Clean up this active call
            activeCalls[callId] = nil
        }

        activeCalls[callId] = task
    }

    /// Send function result back to Azure conversation
    /// - Parameters:
    ///   - callId: The call ID from the function call request
    ///   - output: JSON string output from the function
    private func sendFunctionResult(callId: String, output: String) async throws {
        // Create function output item using helper from AzureConfigurationHelpers
        let outputItem = RealtimeConversationRequestItem.functionOutput(
            callId: callId,
            output: output
        )

        // Send to conversation (note: create takes item first, after second)
        try await azureService.conversation.items.create(outputItem, after: nil)

        AppLogger.azure.debug("📤 Sent function result for call_id: \(callId)")
    }

    /// Cancel all active function calls
    public func cancelAll() {
        let count = activeCalls.count
        if count > 0 {
            AppLogger.azure.info("Cancelling \(count) active function call(s)")
        }

        activeCalls.values.forEach { $0.cancel() }
        activeCalls.removeAll()
    }
}

// MARK: - AzureServiceProtocol

/// Protocol for Azure service to allow testing and decoupling
public protocol AzureServiceProtocol: Actor {
    var response: Response { get }
    var conversation: Conversation { get }
}

// Make VoiceLiveConnection conform to AzureServiceProtocol
extension VoiceLiveConnection: AzureServiceProtocol {}
