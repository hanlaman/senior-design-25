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

    /// Published array of user-visible tools that can be toggled
    @Published public private(set) var availableTools: [LocalFunctionTool]

    /// Hidden tools that are always enabled and not shown in UI
    @Published public private(set) var hiddenTools: [LocalFunctionTool]

    /// Published array of toolsets for organizing visible tools
    @Published public private(set) var toolsets: [Toolset]

    private let settingsManager: ToolSettingsManager

    private init() {
        self.settingsManager = ToolSettingsManager.shared

        // Define toolsets (for visible tools only)
        self.toolsets = [
            Toolset(id: "Utilities", icon: "wrench.and.screwdriver")
        ]

        // Initialize with user-visible tools
        self.availableTools = [
            LocalFunctionTool(
                id: "get_current_time",
                name: "get_current_time",
                description: LLMPrompts.Tools.getCurrentTime,
                displayName: "Current Time",
                shortDescription: "Get the time",
                toolsetId: "Utilities",
                isEnabled: true,
                isHidden: false,
                parameters: [:],
                handler: .getCurrentTime
            ),
            LocalFunctionTool(
                id: "create_reminder",
                name: "create_reminder",
                description: LLMPrompts.Tools.createReminder,
                displayName: "Create Reminder",
                shortDescription: "Set a new reminder",
                toolsetId: "Utilities",
                isEnabled: true,
                isHidden: false,
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": [
                            "type": "string",
                            "description": LLMPrompts.Tools.createReminderTitleParam
                        ],
                        "scheduledTime": [
                            "type": "string",
                            "description": LLMPrompts.Tools.createReminderTimeParam
                        ],
                        "type": [
                            "type": "string",
                            "description": LLMPrompts.Tools.createReminderTypeParam
                        ],
                        "notes": [
                            "type": "string",
                            "description": LLMPrompts.Tools.createReminderNotesParam
                        ],
                        "repeatSchedule": [
                            "type": "string",
                            "description": LLMPrompts.Tools.createReminderRepeatParam
                        ]
                    ]),
                    "required": AnyCodable(["title", "scheduledTime"])
                ],
                handler: .createReminder
            ),
            LocalFunctionTool(
                id: "call_caregiver",
                name: "call_caregiver",
                description: LLMPrompts.Tools.callCaregiver,
                displayName: "Call Caregiver",
                shortDescription: "Call your caregiver",
                toolsetId: "Utilities",
                isEnabled: true,
                isHidden: false,
                parameters: [:],
                handler: .callCaregiver
            ),
            LocalFunctionTool(
                id: "get_weather",
                name: "get_weather",
                description: LLMPrompts.Tools.getWeather,
                displayName: "Weather",
                shortDescription: "Get current weather",
                toolsetId: "Utilities",
                isEnabled: true,
                isHidden: false,
                parameters: [:],
                handler: .getWeather
            )
        ]

        // Initialize hidden tools (always enabled, not shown in UI)
        self.hiddenTools = [
            LocalFunctionTool(
                id: "get_session_transcript",
                name: "get_session_transcript",
                description: LLMPrompts.Tools.getSessionTranscript,
                displayName: "Session Transcript",
                shortDescription: "Get conversation history",
                toolsetId: "System",
                isEnabled: true,
                isHidden: true,
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "max_messages": [
                            "type": "integer",
                            "description": LLMPrompts.Tools.getSessionTranscriptMaxMessagesParam
                        ]
                    ])
                ],
                handler: .getSessionTranscript
            ),
            LocalFunctionTool(
                id: "get_user_memories",
                name: "get_user_memories",
                description: LLMPrompts.Tools.getUserMemories,
                displayName: "User Memories",
                shortDescription: "Get relevant user memories",
                toolsetId: "System",
                isEnabled: true,
                isHidden: true,
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "query": [
                            "type": "string",
                            "description": LLMPrompts.Tools.getUserMemoriesQueryParam
                        ]
                    ]),
                    "required": AnyCodable(["query"])
                ],
                handler: .getUserMemories
            ),
            LocalFunctionTool(
                id: "get_patient_facts",
                name: "get_patient_facts",
                description: LLMPrompts.Tools.getPatientFacts,
                displayName: "Patient Facts",
                shortDescription: "Get caregiver-provided patient info",
                toolsetId: "System",
                isEnabled: true,
                isHidden: true,
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([String: Any]())
                ],
                handler: .getPatientFacts
            ),
            LocalFunctionTool(
                id: "get_current_location",
                name: "get_current_location",
                description: LLMPrompts.Tools.getCurrentLocation,
                displayName: "Current Location",
                shortDescription: "Get user's current location",
                toolsetId: "System",
                isEnabled: true,
                isHidden: true,
                parameters: [:],
                handler: .getCurrentLocation
            ),
            LocalFunctionTool(
                id: "get_reminders",
                name: "get_reminders",
                description: LLMPrompts.Tools.getReminders,
                displayName: "Reminders",
                shortDescription: "Get upcoming reminders",
                toolsetId: "System",
                isEnabled: true,
                isHidden: true,
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "date": [
                            "type": "string",
                            "description": LLMPrompts.Tools.getRemindersDateParam
                        ]
                    ])
                ],
                handler: .getReminders
            ),
            LocalFunctionTool(
                id: "notify_caregiver",
                name: "notify_caregiver",
                description: LLMPrompts.Tools.notifyCaregiver,
                displayName: "Notify Caregiver",
                shortDescription: "Alert the caregiver",
                toolsetId: "System",
                isEnabled: true,
                isHidden: true,
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "message": [
                            "type": "string",
                            "description": LLMPrompts.Tools.notifyCaregiverMessageParam
                        ],
                        "alert_type": [
                            "type": "string",
                            "description": LLMPrompts.Tools.notifyCaregiverAlertTypeParam
                        ]
                    ]),
                    "required": AnyCodable(["message", "alert_type"])
                ],
                handler: .notifyCaregiver
            )
        ]

        // Load enabled state from settings manager
        updateToolStates()

        AppLogger.general.info("ToolRegistry initialized with \(self.availableTools.count) visible and \(self.hiddenTools.count) hidden tool(s)")
    }

    /// Toggle the enabled state of a tool
    /// - Parameter id: Unique identifier of the tool to toggle
    public func toggleTool(id: String) {
        // Hidden tools cannot be toggled
        if hiddenTools.contains(where: { $0.id == id }) {
            AppLogger.general.warning("Attempted to toggle hidden tool: \(id)")
            return
        }

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

    /// Get array of enabled tools in Azure API format (includes hidden tools)
    /// - Returns: Array of RealtimeTool objects for enabled and hidden tools
    public func getEnabledTools() -> [RealtimeTool] {
        // Get enabled visible tools
        let enabledVisibleTools = availableTools
            .filter { $0.isEnabled }
            .map { $0.toRealtimeTool() }

        // Hidden tools are always included
        let hiddenToolsList = hiddenTools
            .map { $0.toRealtimeTool() }

        let allTools = enabledVisibleTools + hiddenToolsList
        AppLogger.general.debug("Returning \(allTools.count) tools (\(enabledVisibleTools.count) visible, \(hiddenToolsList.count) hidden)")
        return allTools
    }

    /// Find a tool by its name (searches both visible and hidden tools)
    /// - Parameter name: Name of the tool to find
    /// - Returns: The tool if found and enabled (or hidden), nil otherwise
    public func findTool(byName name: String) -> LocalFunctionTool? {
        // First check visible enabled tools
        if let tool = availableTools.first(where: { $0.name == name && $0.isEnabled }) {
            return tool
        }

        // Then check hidden tools (always enabled)
        if let tool = hiddenTools.first(where: { $0.name == name }) {
            return tool
        }

        AppLogger.general.debug("Tool '\(name)' not found or not enabled")
        return nil
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
