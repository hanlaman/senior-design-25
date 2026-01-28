//
//  PatientAlert.swift
//  caregiverapp
//

import Foundation
import SwiftUI

struct PatientAlert: Identifiable, Codable {
    let id: UUID
    let type: AlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let timestamp: Date
    var isAcknowledged: Bool
    var acknowledgedAt: Date?
    var acknowledgedBy: String?

    init(
        id: UUID = UUID(),
        type: AlertType,
        severity: AlertSeverity,
        title: String,
        message: String,
        timestamp: Date = Date(),
        isAcknowledged: Bool = false,
        acknowledgedAt: Date? = nil,
        acknowledgedBy: String? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isAcknowledged = isAcknowledged
        self.acknowledgedAt = acknowledgedAt
        self.acknowledgedBy = acknowledgedBy
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

enum AlertType: String, Codable, CaseIterable {
    case fall = "fall"
    case heartRate = "heart_rate"
    case geofence = "geofence"
    case inactivity = "inactivity"
    case medication = "medication"
    case sos = "sos"
    case connection = "connection"

    var icon: String {
        switch self {
        case .fall: return "figure.fall"
        case .heartRate: return "heart.fill"
        case .geofence: return "location.slash.fill"
        case .inactivity: return "figure.stand"
        case .medication: return "pills.fill"
        case .sos: return "sos"
        case .connection: return "applewatch.slash"
        }
    }

    var color: Color {
        switch self {
        case .fall: return .red
        case .heartRate: return .red
        case .geofence: return .orange
        case .inactivity: return .yellow
        case .medication: return .blue
        case .sos: return .red
        case .connection: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .fall: return "Fall Detected"
        case .heartRate: return "Heart Rate"
        case .geofence: return "Location"
        case .inactivity: return "Inactivity"
        case .medication: return "Medication"
        case .sos: return "Emergency SOS"
        case .connection: return "Connection"
        }
    }
}

enum AlertSeverity: String, Codable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        let order: [AlertSeverity] = [.low, .medium, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
