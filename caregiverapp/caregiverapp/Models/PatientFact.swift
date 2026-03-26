//
//  PatientFact.swift
//  caregiverapp
//
//  A factual piece of information about a patient, entered by a caregiver.
//  These facts are sent to the backend and injected into the watch voice
//  assistant's context so the AI has personalized knowledge about the patient.
//

import Foundation

enum FactCategory: String, CaseIterable, Codable {
    case personal
    case family
    case medical
    case routine
    case preference
    case other

    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .family: return "Family & Relationships"
        case .medical: return "Medical"
        case .routine: return "Daily Routine"
        case .preference: return "Preferences"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .family: return "person.2.fill"
        case .medical: return "cross.case.fill"
        case .routine: return "clock.fill"
        case .preference: return "star.fill"
        case .other: return "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .personal: return "blue"
        case .family: return "purple"
        case .medical: return "red"
        case .routine: return "orange"
        case .preference: return "green"
        case .other: return "gray"
        }
    }
}

struct PatientFact: Identifiable, Codable {
    let id: UUID
    var category: FactCategory
    var label: String
    var value: String

    init(
        id: UUID = UUID(),
        category: FactCategory,
        label: String,
        value: String
    ) {
        self.id = id
        self.category = category
        self.label = label
        self.value = value
    }
}
