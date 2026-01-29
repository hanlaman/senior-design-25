//
//  Location.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: WORKING WITH EXTERNAL FRAMEWORKS AND METHODS
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import CoreLocation  // Apple's framework for GPS/location services

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ WHY NOT USE CLLocationCoordinate2D DIRECTLY?                                │
// │                                                                             │
// │ CoreLocation's CLLocationCoordinate2D is NOT Codable.                       │
// │ We need Codable to save/load data and sync with Firebase.                  │
// │                                                                             │
// │ Solution: Create our own Coordinate struct that IS Codable,                │
// │ then convert to/from CLLocationCoordinate2D when needed.                   │
// └─────────────────────────────────────────────────────────────────────────────┘

struct PatientLocation: Codable {
    var coordinate: Coordinate
    var timestamp: Date
    var isInSafeZone: Bool
    var currentZoneName: String?  // nil if not in any zone
    var address: String?          // nil if reverse geocoding hasn't run

    init(
        coordinate: Coordinate,
        timestamp: Date = Date(),
        isInSafeZone: Bool = true,
        currentZoneName: String? = nil,
        address: String? = nil
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.isInSafeZone = isInSafeZone
        self.currentZoneName = currentZoneName
        self.address = address
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ CONVERTING BETWEEN TYPES                                                │
    // │                                                                         │
    // │ clLocation converts our Coordinate to Apple's CLLocationCoordinate2D.  │
    // │ This is needed because MapKit/CoreLocation use their own types.        │
    // │                                                                         │
    // │ This pattern is common when working with external frameworks:           │
    // │   1. Store data in your own Codable types                              │
    // │   2. Convert to framework types only when needed                       │
    // └─────────────────────────────────────────────────────────────────────────┘
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

struct Coordinate: Codable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ MULTIPLE INITIALIZERS                                                   │
    // │                                                                         │
    // │ A struct/class can have multiple initializers for convenience.         │
    // │ This init creates a Coordinate from a CLLocationCoordinate2D.          │
    // │                                                                         │
    // │ PARAMETER LABELS:                                                       │
    // │   init(from clCoordinate: CLLocationCoordinate2D)                      │
    // │         ↑      ↑                                                        │
    // │       external internal                                                 │
    // │                                                                         │
    // │ Usage: Coordinate(from: someCLCoordinate)                              │
    // │                                                                         │
    // │ The 'from' label makes the call site read naturally:                   │
    // │   "Create a Coordinate FROM this CLLocationCoordinate2D"               │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(from clCoordinate: CLLocationCoordinate2D) {
        self.latitude = clCoordinate.latitude
        self.longitude = clCoordinate.longitude
    }
}

struct SafeZone: Identifiable, Codable {
    let id: UUID
    var name: String
    var center: Coordinate
    var radiusMeters: Double
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        center: Coordinate,
        radiusMeters: Double = 100,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.center = center
        self.radiusMeters = radiusMeters
        self.isEnabled = isEnabled
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ METHODS (FUNCTIONS INSIDE TYPES)                                        │
    // │                                                                         │
    // │ Functions inside structs/classes/enums are called METHODS.             │
    // │ They have implicit access to 'self' (the current instance).            │
    // │                                                                         │
    // │ FUNCTION SYNTAX:                                                        │
    // │   func name(param: Type) -> ReturnType { body }                        │
    // │                                                                         │
    // │ If a method doesn't return anything, omit -> ReturnType                │
    // │ or use -> Void                                                          │
    // │                                                                         │
    // │ CALLING METHODS:                                                        │
    // │   let zone = SafeZone(...)                                              │
    // │   let isInside = zone.contains(location: patientLocation)              │
    // └─────────────────────────────────────────────────────────────────────────┘
    func contains(location: PatientLocation) -> Bool {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ TYPE INFERENCE                                                      │
        // │                                                                     │
        // │ Swift can INFER types, so you often don't need to specify them.    │
        // │                                                                     │
        // │   let zoneCenter = CLLocation(...)                                 │
        // │                                                                     │
        // │ Swift figures out zoneCenter is a CLLocation from the right side.  │
        // │ You could also write:                                              │
        // │                                                                     │
        // │   let zoneCenter: CLLocation = CLLocation(...)                     │
        // │                                                                     │
        // │ But that's redundant. Only add type annotations when:              │
        // │   1. The compiler can't infer the type                             │
        // │   2. You want to be explicit for clarity                           │
        // │   3. You want a more general type (protocol instead of concrete)   │
        // └─────────────────────────────────────────────────────────────────────┘
        let zoneCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let patientLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ METHOD CHAINING & COMPARISON                                        │
        // │                                                                     │
        // │ zoneCenter.distance(from:) returns a Double (meters)               │
        // │ We compare it with <= to get a Bool                                │
        // │                                                                     │
        // │ The entire expression evaluates to true/false, which we return.    │
        // │ No need for: if distance <= radius { return true } else { false }  │
        // └─────────────────────────────────────────────────────────────────────┘
        return zoneCenter.distance(from: patientLocation) <= radiusMeters
    }
}
