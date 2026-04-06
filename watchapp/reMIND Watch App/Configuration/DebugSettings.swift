//
//  DebugSettings.swift
//  reMIND Watch App
//
//  Debug settings for development and simulator testing
//

import Foundation
import Combine

/// Debug settings for development and simulator testing
class DebugSettings: ObservableObject {
    static let shared = DebugSettings()

    private let userDefaults = UserDefaults.standard
    private let timeoutsDisabledKey = "debug_timeoutsDisabled"

    /// When true, connection-lifecycle timeouts are set to infinity
    /// so the app won't self-disconnect during long simulator sessions.
    @Published var timeoutsDisabled: Bool {
        didSet {
            userDefaults.set(timeoutsDisabled, forKey: timeoutsDisabledKey)
        }
    }

    private init() {
        self.timeoutsDisabled = userDefaults.bool(forKey: timeoutsDisabledKey)
    }
}
