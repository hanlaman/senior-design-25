//
//  TestHelpers.swift
//  reMIND Watch AppTests
//
//  Common test utilities and helpers
//

import Foundation
import XCTest
@testable import reMIND_Watch_App

// MARK: - Test Data Factories

/// Factory methods for creating test data
enum TestData {
    /// Create a test session ID
    static func sessionId() -> String {
        "test-session-\(UUID().uuidString.prefix(8))"
    }

    /// Create test audio data
    static func audioData(bytes: Int = 4800) -> Data {
        Data(repeating: 0, count: bytes)
    }

    /// Create test VoiceSettings with defaults
    static func voiceSettings(
        speakingRate: Double = 1.0,
        continuousListeningEnabled: Bool = false
    ) -> VoiceSettings {
        var settings = VoiceSettings.defaultSettings
        settings.speakingRate = speakingRate
        settings.continuousListeningEnabled = continuousListeningEnabled
        return settings
    }

    /// Create a test LocalFunctionTool
    static func functionTool(
        id: String = "test_tool",
        name: String = "test_tool",
        isEnabled: Bool = true
    ) -> LocalFunctionTool {
        LocalFunctionTool(
            id: id,
            name: name,
            description: "A test tool for unit testing",
            displayName: "Test Tool",
            shortDescription: "Test",
            toolsetId: "TestToolset",
            isEnabled: isEnabled,
            parameters: [:],
            handler: .getCurrentTime
        )
    }
}

// MARK: - Async Test Utilities

/// Utilities for async testing
enum AsyncTestUtils {
    /// Wait for a condition to become true
    static func waitUntil(
        timeout: TimeInterval = 2.0,
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()
        while !(await condition()) {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TestError.timeout
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    /// Wait for a value to change
    static func waitForChange<T: Equatable>(
        initial: T,
        timeout: TimeInterval = 2.0,
        getValue: @escaping () async -> T
    ) async throws -> T {
        let startTime = Date()
        var current = await getValue()
        while current == initial {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TestError.timeout
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            current = await getValue()
        }
        return current
    }
}

// MARK: - Test Errors

enum TestError: LocalizedError {
    case timeout
    case unexpectedState(String)
    case mockNotConfigured

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Test timed out waiting for condition"
        case .unexpectedState(let message):
            return "Unexpected state: \(message)"
        case .mockNotConfigured:
            return "Mock was not properly configured for this test"
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    /// Wait for an async condition to become true
    @MainActor
    func waitForCondition(
        timeout: TimeInterval = 2.0,
        description: String = "Condition",
        condition: @escaping () async -> Bool
    ) async {
        let expectation = self.expectation(description: description)

        Task {
            let startTime = Date()
            while !(await condition()) {
                if Date().timeIntervalSince(startTime) > timeout {
                    break
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: timeout + 1.0)
    }
}
