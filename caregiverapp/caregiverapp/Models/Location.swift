//
//  Location.swift
//  caregiverapp
//

import Foundation
import CoreLocation

struct PatientLocation: Codable {
    var coordinate: Coordinate
    var timestamp: Date
    var isInSafeZone: Bool
    var currentZoneName: String?
    var address: String?

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

    func contains(location: PatientLocation) -> Bool {
        let zoneCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let patientLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        return zoneCenter.distance(from: patientLocation) <= radiusMeters
    }
}
