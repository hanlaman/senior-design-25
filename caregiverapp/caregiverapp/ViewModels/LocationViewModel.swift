//
//  LocationViewModel.swift
//  caregiverapp
//
//  ViewModel for location tracking, safe zone management, and geofence evaluation.
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
    private(set) var hasLoadedInitialData: Bool = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    var isInSafeZone: Bool { currentLocation?.isInSafeZone ?? true }
    var currentZoneName: String? { currentLocation?.currentZoneName }

    var locationStatusText: String {
        if let location = currentLocation {
            let enabledZones = safeZones.filter { $0.isEnabled }
            if enabledZones.isEmpty {
                return "No Safe Zones Configured"
            }
            return location.isInSafeZone ? "In Safe Zone: \(location.currentZoneName ?? "Unknown")" : "Outside Safe Zones"
        }
        return "Location Unknown"
    }

    private let dataProvider: PatientDataProvider
    private let locationAPIService = LocationAPIService()
    private var cancellables = Set<AnyCancellable>()
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 10
    private var previouslyInsideZoneIds: Set<UUID> = []

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.locationPublisher.receive(on: DispatchQueue.main).sink { [weak self] location in
            guard let self else { return }
            if let location {
                let evaluated = self.evaluateGeofences(location)
                self.currentLocation = evaluated
                self.locationHistory.append(evaluated)
                if self.locationHistory.count > 100 { self.locationHistory.removeFirst() }
            } else {
                self.currentLocation = nil
            }
        }.store(in: &cancellables)
    }

    func onAppear() {
        Task { await loadInitialData() }
    }

    func retry() {
        Task { await loadInitialData() }
    }

    private func loadInitialData() async {
        isLoading = true
        errorMessage = nil

        async let locationResult = locationAPIService.fetchLatestLocation()
        async let zonesResult = locationAPIService.fetchSafeZones()

        let location = await locationResult
        let zones = await zonesResult

        if location == nil && zones.isEmpty {
            errorMessage = "Unable to connect to server. Check your connection and try again."
            isLoading = false
            return
        }

        safeZones = zones

        if let location {
            let evaluated = evaluateGeofences(location)
            currentLocation = evaluated
            lastUpdated = Date()
        }

        // Seed geofence state to prevent false alerts on first poll
        if let location = currentLocation {
            let enabledZones = safeZones.filter { $0.isEnabled }
            previouslyInsideZoneIds = Set(enabledZones.filter { $0.contains(location: location) }.map { $0.id })
        }

        hasLoadedInitialData = true
        isLoading = false
        startPolling()
    }

    func onDisappear() {
        stopPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollLocation()
                try? await Task.sleep(for: .seconds(self?.pollingInterval ?? 60))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollLocation() async {
        if let location = await locationAPIService.fetchLatestLocation() {
            errorMessage = nil
            let evaluatedLocation = evaluateGeofences(location)
            currentLocation = evaluatedLocation
            lastUpdated = Date()
            locationHistory.append(evaluatedLocation)
            if locationHistory.count > 100 { locationHistory.removeFirst() }
        }
    }

    // MARK: - Geofence Evaluation

    private func evaluateGeofences(_ location: PatientLocation) -> PatientLocation {
        let enabledZones = safeZones.filter { $0.isEnabled }
        var updatedLocation = location

        // No enabled zones configured — don't flag patient as outside
        if enabledZones.isEmpty {
            updatedLocation.isInSafeZone = true
            updatedLocation.currentZoneName = nil
            previouslyInsideZoneIds = []
            return updatedLocation
        }

        let containingZones = enabledZones.filter { $0.contains(location: location) }
        let currentZoneIds = Set(containingZones.map { $0.id })

        if let firstZone = containingZones.first {
            updatedLocation.isInSafeZone = true
            updatedLocation.currentZoneName = firstZone.name
        } else {
            updatedLocation.isInSafeZone = false
            updatedLocation.currentZoneName = nil
        }

        // Detect exit transitions (only if we had previous state)
        let exitedZoneIds = previouslyInsideZoneIds.subtracting(currentZoneIds)
        if !exitedZoneIds.isEmpty && !previouslyInsideZoneIds.isEmpty {
            let exitedZoneNames = enabledZones
                .filter { exitedZoneIds.contains($0.id) }
                .map { $0.name }
                .joined(separator: ", ")
            generateGeofenceAlert(zoneNames: exitedZoneNames)
        }

        previouslyInsideZoneIds = currentZoneIds
        return updatedLocation
    }

    private func generateGeofenceAlert(zoneNames: String) {
        let alert = PatientAlert(
            type: .geofence,
            severity: .high,
            title: "Left Safe Zone",
            message: "Patient has left: \(zoneNames)",
            timestamp: Date()
        )
        Task { try? await dataProvider.addAlert(alert) }
    }

    // MARK: - Safe Zone CRUD

    func addSafeZone(name: String, center: CLLocationCoordinate2D, radius: Double, durationMinutes: Int = 15) {
        let zone = SafeZone(name: name, center: Coordinate(from: center), radiusMeters: radius, durationMinutes: durationMinutes)
        safeZones.append(zone)
        Task {
            _ = await locationAPIService.createSafeZone(zone)
        }
    }

    func removeSafeZone(_ zone: SafeZone) {
        safeZones.removeAll { $0.id == zone.id }
        Task {
            _ = await locationAPIService.deleteSafeZone(id: zone.id)
        }
    }

    func updateSafeZone(_ zone: SafeZone, newRadius: Double, newDuration: Int) {
        var updatedZone = zone
        updatedZone.radiusMeters = newRadius
        updatedZone.durationMinutes = newDuration
        if let index = safeZones.firstIndex(where: { $0.id == zone.id }) {
            safeZones[index] = updatedZone
        }
        Task {
            _ = await locationAPIService.updateSafeZone(updatedZone)
        }
    }

    func toggleSafeZone(_ zone: SafeZone) {
        var updatedZone = zone
        updatedZone.isEnabled.toggle()
        if let index = safeZones.firstIndex(where: { $0.id == zone.id }) {
            safeZones[index] = updatedZone
        }
        Task {
            _ = await locationAPIService.updateSafeZone(updatedZone)
        }
    }

    func centerOnPatient() -> MKCoordinateRegion? {
        guard let location = currentLocation else { return nil }
        return MKCoordinateRegion(center: location.clLocation, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
    }
}
