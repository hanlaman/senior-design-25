//
//  Patient.swift
//  caregiverapp
//

import Foundation

struct Patient: Identifiable, Codable {
    let id: UUID
    var name: String
    var age: Int
    var photoURL: String?
    var conditions: [String]
    var emergencyContacts: [EmergencyContact]

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        photoURL: String? = nil,
        conditions: [String] = [],
        emergencyContacts: [EmergencyContact] = []
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.photoURL = photoURL
        self.conditions = conditions
        self.emergencyContacts = emergencyContacts
    }
}

struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var relationship: String
    var phoneNumber: String

    init(id: UUID = UUID(), name: String, relationship: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.phoneNumber = phoneNumber
    }
}
