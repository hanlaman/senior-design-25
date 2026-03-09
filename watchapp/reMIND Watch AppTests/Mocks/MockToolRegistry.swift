//
//  MockToolRegistry.swift
//  reMIND Watch AppTests
//
//  Mock tool registry for testing
//

import Foundation
import Combine
@testable import reMIND_Watch_App

/// Mock tool registry for testing
/// Inherits from ToolRegistry to maintain compatibility with existing code
@MainActor
class MockToolRegistry: ObservableObject {
    // MARK: - Test Control Properties

    /// Whether getEnabledTools was called
    private(set) var getEnabledToolsCalled = false

    /// Whether findTool was called
    private(set) var findToolCalled = false

    /// Tool names passed to findTool
    private(set) var findToolNames: [String] = []

    /// Whether toggleTool was called
    private(set) var toggleToolCalled = false

    /// Tool IDs passed to toggleTool
    private(set) var toggledToolIds: [String] = []

    /// Whether tool execution should fail
    var shouldFailExecution = false

    /// Custom error to return on execution failure
    var executionError: Error?

    // MARK: - Mock Data

    /// Available tools (observable)
    @Published private(set) var availableTools: [LocalFunctionTool]

    /// Toolsets
    @Published private(set) var toolsets: [Toolset]

    // MARK: - Initialization

    init(tools: [LocalFunctionTool] = [], toolsets: [Toolset] = []) {
        self.availableTools = tools
        self.toolsets = toolsets
    }

    // MARK: - Mock Methods (matching ToolRegistry interface)

    func toggleTool(id: String) {
        toggleToolCalled = true
        toggledToolIds.append(id)

        if let index = availableTools.firstIndex(where: { $0.id == id }) {
            availableTools[index].isEnabled.toggle()
        }
    }

    func getEnabledTools() -> [RealtimeTool] {
        getEnabledToolsCalled = true
        return availableTools
            .filter { $0.isEnabled }
            .map { $0.toRealtimeTool() }
    }

    func findTool(byName name: String) -> LocalFunctionTool? {
        findToolCalled = true
        findToolNames.append(name)
        return availableTools.first { $0.name == name && $0.isEnabled }
    }

    func tools(inToolset toolsetId: String) -> [LocalFunctionTool] {
        return availableTools.filter { $0.toolsetId == toolsetId }
    }

    func toolset(withId id: String) -> Toolset? {
        return toolsets.first { $0.id == id }
    }

    // MARK: - Test Control Methods

    /// Add a tool to the registry
    func addTool(_ tool: LocalFunctionTool) {
        availableTools.append(tool)
    }

    /// Remove a tool from the registry
    func removeTool(id: String) {
        availableTools.removeAll { $0.id == id }
    }

    /// Set tool enabled state directly
    func setToolEnabled(_ id: String, _ enabled: Bool) {
        if let index = availableTools.firstIndex(where: { $0.id == id }) {
            availableTools[index].isEnabled = enabled
        }
    }

    /// Reset all test state
    func reset() {
        getEnabledToolsCalled = false
        findToolCalled = false
        findToolNames.removeAll()
        toggleToolCalled = false
        toggledToolIds.removeAll()
        shouldFailExecution = false
        executionError = nil
        availableTools.removeAll()
        toolsets.removeAll()
    }

    /// Create a default test tool
    static func createTestTool(
        id: String = "test_tool",
        name: String = "test_tool",
        description: String = "A test tool",
        isEnabled: Bool = true
    ) -> LocalFunctionTool {
        return LocalFunctionTool(
            id: id,
            name: name,
            description: description,
            displayName: "Test Tool",
            shortDescription: "Test",
            toolsetId: "TestToolset",
            isEnabled: isEnabled,
            parameters: [:],
            handler: .getCurrentTime // Use existing handler for testing
        )
    }

    /// Populate with default test tools
    func populateWithDefaultTools() {
        availableTools = [
            Self.createTestTool(
                id: "get_current_time",
                name: "get_current_time",
                description: "Get the current time",
                isEnabled: true
            )
        ]
        toolsets = [
            Toolset(id: "TestToolset", icon: "wrench")
        ]
    }
}
