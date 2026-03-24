//
//  LocationService.swift
//  reMIND Watch App
//
//  Tracks device location and sends updates to the API server.
//

import CoreLocation
import Foundation
import os

actor LocationService: NSObject {
    private let locationManager = CLLocationManager()
    private let baseURL: String
    private let patientId: String
    private let updateInterval: TimeInterval

    private var delegate: LocationDelegate?
    private var sendTask: Task<Void, Never>?

    private(set) var lastLocation: CLLocation?
    private(set) var isTracking = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var locationContinuation: AsyncStream<CLLocation>.Continuation?
    let locationStream: AsyncStream<CLLocation>

    init(
        baseURL: String = "http://localhost:3000",
        patientId: String = "demo-patient-1",
        updateInterval: TimeInterval = 15
    ) {
        var continuationHolder: AsyncStream<CLLocation>.Continuation?
        self.locationStream = AsyncStream { continuation in
            continuationHolder = continuation
        }

        self.baseURL = baseURL
        self.patientId = patientId
        self.updateInterval = updateInterval

        super.init()

        self.locationContinuation = continuationHolder
    }

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true

        let delegate = LocationDelegate { [weak self] location in
            Task { await self?.handleLocationUpdate(location) }
        } onAuthorizationChange: { [weak self] status in
            Task { await self?.handleAuthorizationChange(status) }
        }
        self.delegate = delegate

        locationManager.delegate = delegate

        // watchOS battery optimization: Use reduced accuracy for location tracking
        // kCLLocationAccuracyHundredMeters is sufficient for caregiver monitoring
        // and uses significantly less battery than kCLLocationAccuracyBest
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // Only send location updates when user moves 50+ meters
        // Prevents constant updates from GPS drift when stationary
        locationManager.distanceFilter = 50 // meters

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        AppLogger.general.info("Location tracking started (accuracy: 100m, filter: 50m)")

        startPeriodicSending()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        delegate = nil
        sendTask?.cancel()
        sendTask = nil
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        lastLocation = location
        locationContinuation?.yield(location)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    private func startPeriodicSending() {
        sendTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.updateInterval ?? 60))
                guard !Task.isCancelled else { break }
                await self?.sendLocationToServer()
            }
        }
    }

    private func sendLocationToServer() async {
        guard let location = lastLocation else {
            AppLogger.general.debug("No location available to send")
            return
        }

        // Check if location is recent (< 5 minutes old)
        let locationAge = Date().timeIntervalSince(location.timestamp)
        guard locationAge < 300 else {
            AppLogger.general.warning("Location too old (\(locationAge)s), skipping send")
            return
        }

        let url = URL(string: "\(baseURL)/location")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = LocationConfiguration.requestTimeout

        let body: [String: Any] = [
            "patientId": patientId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
            "accuracy": location.horizontalAccuracy,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    AppLogger.general.info("Location sent: lat=\(String(format: "%.4f", location.coordinate.latitude)), lon=\(String(format: "%.4f", location.coordinate.longitude)), accuracy=±\(Int(location.horizontalAccuracy))m")
                } else {
                    AppLogger.general.warning("Location send failed with status \(httpResponse.statusCode)")
                }
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to send location")
        }
    }
}

// CLLocationManager delegate must be an NSObject class (not an actor)
private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onLocationUpdate: (CLLocation) -> Void
    let onAuthorizationChange: (CLAuthorizationStatus) -> Void

    init(
        onLocationUpdate: @escaping (CLLocation) -> Void,
        onAuthorizationChange: @escaping (CLAuthorizationStatus) -> Void
    ) {
        self.onLocationUpdate = onLocationUpdate
        self.onAuthorizationChange = onAuthorizationChange
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate(location)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationDelegate] Location error: \(error.localizedDescription)")
    }
}
