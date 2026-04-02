//
//  RetryHelper.swift
//  reMIND Watch App
//
//  Shared retry utility with exponential backoff for network requests
//

import Foundation

enum RetryHelper {
    /// Execute an operation with exponential backoff retry
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - initialDelay: Delay before first retry in seconds (default: 2)
    ///   - operation: The async throwing operation to retry
    /// - Returns: The result of the operation
    static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 2,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError!
    }
}
