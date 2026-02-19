//
//  LocationViewModel.swift
//  reMIND Watch App
//
//  Manages location tracking lifecycle and exposes state to views.
//

import Combine
import CoreLocation
import Foundation

@MainActor
class LocationViewModel: ObservableObject {
    @Published private(set) var isTracking = false
    @Published private(set) var lastLatitude: Double?
    @Published private(set) var lastLongitude: Double?

    private var locationService: LocationService?
    private var observeTask: Task<Void, Never>?

    func startTracking() async {
        let service = LocationService()
        self.locationService = service

        observeTask = Task {
            for await location in service.locationStream {
                self.lastLatitude = location.coordinate.latitude
                self.lastLongitude = location.coordinate.longitude
                self.isTracking = true
            }
        }

        await service.startTracking()
    }

    func stopTracking() async {
        observeTask?.cancel()
        observeTask = nil
        await locationService?.stopTracking()
        locationService = nil
        isTracking = false
    }

    var locationText: String {
        if let lat = lastLatitude, let lon = lastLongitude {
            return String(format: "%.4f, %.4f", lat, lon)
        }
        return "Waiting for location..."
    }
}
