//
//  ToolRegistry.swift
//  reMIND Watch App
//
//  Central registry managing available tools and their enabled state
//

import Foundation
import Combine
import os

/// Singleton registry for managing function tools
@MainActor
public class ToolRegistry: ObservableObject {
    /// Shared singleton instance
    public static let shared = ToolRegistry()

    /// Published array of available tools that views can observe
    @Published public private(set) var availableTools: [LocalFunctionTool]

    /// Published array of toolsets for organizing tools
    @Published public private(set) var toolsets: [Toolset]

    private let settingsManager: ToolSettingsManager

    private init() {
        self.settingsManager = ToolSettingsManager.shared

        // Define toolsets
        self.toolsets = [
            Toolset(id: "Utilities", icon: "wrench.and.screwdriver")
        ]

        // Initialize with built-in tools
        self.availableTools = [
            LocalFunctionTool(
                id: "get_current_time",
                name: "get_current_time",
                description: "Get the current local time in a human-readable format",
                displayName: "Current Time",
                shortDescription: "Get the time",
                toolsetId: "Utilities",
                isEnabled: true,
                parameters: [:],
                handler: .getCurrentTime
            )
            // Future tools will be added here
        ]

        // Load enabled state from settings manager
        updateToolStates()

        AppLogger.general.info("ToolRegistry initialized with \(self.availableTools.count) tool(s) in \(self.toolsets.count) toolset(s)")
    }

    /// Toggle the enabled state of a tool
    /// - Parameter id: Unique identifier of the tool to toggle
    public func toggleTool(id: String) {
        guard let index = availableTools.firstIndex(where: { $0.id == id }) else {
            AppLogger.general.warning("Attempted to toggle unknown tool: \(id)")
            return
        }

        availableTools[index].isEnabled.toggle()
        let newState = availableTools[index].isEnabled

        // Persist to settings manager
        settingsManager.setToolEnabled(id, newState)

        AppLogger.general.info("Tool '\(id)' toggled to: \(newState)")
    }

    /// Get array of enabled tools in Azure API format
    /// - Returns: Array of RealtimeTool objects for enabled tools
    public func getEnabledTools() -> [RealtimeTool] {
        let enabledTools = availableTools
            .filter { $0.isEnabled }
            .map { $0.toRealtimeTool() }

        AppLogger.general.debug("Returning \(enabledTools.count) enabled tool(s)")
        return enabledTools
    }

    /// Find a tool by its name
    /// - Parameter name: Name of the tool to find
    /// - Returns: The tool if found and enabled, nil otherwise
    public func findTool(byName name: String) -> LocalFunctionTool? {
        let tool = availableTools.first { $0.name == name && $0.isEnabled }

        if tool == nil {
            AppLogger.general.debug("Tool '\(name)' not found or not enabled")
        }

        return tool
    }

    /// Get tools belonging to a specific toolset
    /// - Parameter toolsetId: The toolset identifier
    /// - Returns: Array of tools in the specified toolset
    public func tools(inToolset toolsetId: String) -> [LocalFunctionTool] {
        return availableTools.filter { $0.toolsetId == toolsetId }
    }

    /// Get a toolset by its ID
    /// - Parameter id: The toolset identifier
    /// - Returns: The toolset if found, nil otherwise
    public func toolset(withId id: String) -> Toolset? {
        return toolsets.first { $0.id == id }
    }

    /// Update tool enabled states from settings manager
    private func updateToolStates() {
        for index in availableTools.indices {
            let toolId = availableTools[index].id
            let isEnabled = settingsManager.isToolEnabled(toolId)
            availableTools[index].isEnabled = isEnabled
        }
    }
}
