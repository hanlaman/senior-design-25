//
//  LocationViewModel.swift
//  caregiverapp
//

import Foundation
import Combine
import MapKit

@MainActor
@Observable
final class LocationViewModel {
    private(set) var currentLocation: PatientLocation?
    private(set) var safeZones: [SafeZone] = []
    private(set) var locationHistory: [PatientLocation] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    var isInSafeZone: Bool { currentLocation?.isInSafeZone ?? true }
    var currentZoneName: String? { currentLocation?.currentZoneName }

    var locationStatusText: String {
        if let location = currentLocation {
            return location.isInSafeZone ? "In Safe Zone: \(location.currentZoneName ?? "Unknown")" : "Outside Safe Zones"
        }
        return "Location Unknown"
    }

    private let dataProvider: PatientDataProvider
    private var cancellables = Set<AnyCancellable>()

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.locationPublisher.receive(on: DispatchQueue.main).sink { [weak self] location in
            self?.currentLocation = location
            if let location = location {
                self?.locationHistory.append(location)
                if self?.locationHistory.count ?? 0 > 100 { self?.locationHistory.removeFirst() }
            }
        }.store(in: &cancellables)
    }

    func onAppear() {
        currentLocation = dataProvider.currentLocation
        safeZones = dataProvider.safeZones
    }

    func addSafeZone(name: String, center: CLLocationCoordinate2D, radius: Double) {
        let zone = SafeZone(name: name, center: Coordinate(from: center), radiusMeters: radius)
        Task {
            isLoading = true
            defer { isLoading = false }
            try? await dataProvider.addSafeZone(zone)
            safeZones = dataProvider.safeZones
        }
    }

    func removeSafeZone(_ zone: SafeZone) {
        Task { try? await dataProvider.removeSafeZone(id: zone.id); safeZones = dataProvider.safeZones }
    }

    func updateSafeZoneRadius(_ zone: SafeZone, newRadius: Double) {
        var updatedZone = zone
        updatedZone.radiusMeters = newRadius
        Task { try? await dataProvider.updateSafeZone(updatedZone); safeZones = dataProvider.safeZones }
    }

    func toggleSafeZone(_ zone: SafeZone) {
        var updatedZone = zone
        updatedZone.isEnabled.toggle()
        Task { try? await dataProvider.updateSafeZone(updatedZone); safeZones = dataProvider.safeZones }
    }

    func centerOnPatient() -> MKCoordinateRegion? {
        guard let location = currentLocation else { return nil }
        return MKCoordinateRegion(center: location.clLocation, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
    }
}
