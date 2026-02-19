//
//  LocationViewModel.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  ViewModel for location tracking and safe zone management.
//  Demonstrates MKCoordinateRegion and location history tracking.
//  ═══════════════════════════════════════════════════════════════════════════════

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
    private(set) var lastUpdated: Date?

    // Computed properties simplify view logic
    var isInSafeZone: Bool { currentLocation?.isInSafeZone ?? true }
    var currentZoneName: String? { currentLocation?.currentZoneName }

    var locationStatusText: String {
        if let location = currentLocation {
            return location.isInSafeZone ? "In Safe Zone: \(location.currentZoneName ?? "Unknown")" : "Outside Safe Zones"
        }
        return "Location Unknown"
    }

    private let dataProvider: PatientDataProvider
    private let locationAPIService = LocationAPIService()
    private var cancellables = Set<AnyCancellable>()
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 10

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.locationPublisher.receive(on: DispatchQueue.main).sink { [weak self] location in
            self?.currentLocation = location
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ MAINTAINING A HISTORY BUFFER                                    │
            // │                                                                 │
            // │ Appends new locations to history, removing oldest when > 100.  │
            // │ This pattern keeps memory bounded while tracking recent data.  │
            // │                                                                 │
            // │ .count returns the number of elements.                         │
            // │ .removeFirst() removes and returns the first element.          │
            // │ The ?? 0 handles the case where self is nil.                   │
            // └─────────────────────────────────────────────────────────────────┘
            if let location = location {
                self?.locationHistory.append(location)
                if self?.locationHistory.count ?? 0 > 100 { self?.locationHistory.removeFirst() }
            }
        }.store(in: &cancellables)
    }

    func onAppear() {
        currentLocation = dataProvider.currentLocation
        safeZones = dataProvider.safeZones
        startPolling()
    }

    func onDisappear() {
        stopPolling()
    }

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
        print("[LocationViewModel] Polling for location...")
        if let location = await locationAPIService.fetchLatestLocation() {
            print("[LocationViewModel] Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            currentLocation = location
            lastUpdated = Date()
            locationHistory.append(location)
            if locationHistory.count > 100 { locationHistory.removeFirst() }
        } else {
            print("[LocationViewModel] No location received from API")
        }
    }

    func addSafeZone(name: String, center: CLLocationCoordinate2D, radius: Double) {
        let zone = SafeZone(name: name, center: Coordinate(from: center), radiusMeters: radius)
        Task {
            isLoading = true
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ DEFER FOR CLEANUP                                               │
            // │                                                                 │
            // │ defer { isLoading = false } ensures isLoading is set to false  │
            // │ when the scope exits, whether normally or due to an error.     │
            // │ This pattern prevents forgotten loading states.                │
            // └─────────────────────────────────────────────────────────────────┘
            defer { isLoading = false }
            try? await dataProvider.addSafeZone(zone)
            safeZones = dataProvider.safeZones
        }
    }

    func removeSafeZone(_ zone: SafeZone) {
        Task { try? await dataProvider.removeSafeZone(id: zone.id); safeZones = dataProvider.safeZones }
    }

    func updateSafeZoneRadius(_ zone: SafeZone, newRadius: Double) {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ MODIFYING A COPY                                                    │
        // │                                                                     │
        // │ Structs are value types, so 'var updatedZone = zone' creates a copy.│
        // │ We modify the copy, then send it to the data provider.             │
        // │ The original 'zone' is unchanged (it was passed by value).         │
        // └─────────────────────────────────────────────────────────────────────┘
        var updatedZone = zone
        updatedZone.radiusMeters = newRadius
        Task { try? await dataProvider.updateSafeZone(updatedZone); safeZones = dataProvider.safeZones }
    }

    func toggleSafeZone(_ zone: SafeZone) {
        var updatedZone = zone
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .toggle() METHOD                                                    │
        // │                                                                     │
        // │ Bool has a toggle() method that flips true↔false.                  │
        // │ It's mutating, so it changes the value in place.                   │
        // │                                                                     │
        // │ Equivalent to: updatedZone.isEnabled = !updatedZone.isEnabled      │
        // └─────────────────────────────────────────────────────────────────────┘
        updatedZone.isEnabled.toggle()
        Task { try? await dataProvider.updateSafeZone(updatedZone); safeZones = dataProvider.safeZones }
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ RETURNING OPTIONAL FROM FUNCTION                                        │
    // │                                                                         │
    // │ -> MKCoordinateRegion? returns nil if there's no location.             │
    // │ Callers must handle the nil case (if let, guard let, ??, etc.)         │
    // │                                                                         │
    // │ MKCoordinateRegion defines a map area:                                 │
    // │   - center: The center coordinate                                       │
    // │   - span: How much area to show (lat/long deltas)                      │
    // │     - Small delta = zoomed in                                          │
    // │     - Large delta = zoomed out                                         │
    // └─────────────────────────────────────────────────────────────────────────┘
    func centerOnPatient() -> MKCoordinateRegion? {
        guard let location = currentLocation else { return nil }
        return MKCoordinateRegion(center: location.clLocation, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
    }
}
