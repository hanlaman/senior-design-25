//
//  LocationAPIService.swift
//  caregiverapp
//
//  Fetches patient location from the API server.
//

import Foundation

struct LocationResponse: Codable {
    let id: Int
    let patientId: String
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let createdAt: String
}

struct SafeZoneResponse: Codable {
    let id: String
    let patientId: String
    let name: String
    let centerLatitude: Double
    let centerLongitude: Double
    let radiusMeters: Double
    let durationMinutes: Int?
    let isEnabled: Bool
}

@MainActor
final class LocationAPIService {
    private let baseURL: String
    private let patientId: String

    init(baseURL: String = "http://localhost:3000", patientId: String = "demo-patient-1") {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func fetchLatestLocation() async -> PatientLocation? {
        guard let url = URL(string: "\(baseURL)/location/\(patientId)") else {
            print("[LocationAPIService] Invalid URL")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            let locationResponse = try decoder.decode(LocationResponse.self, from: data)

            let coordinate = Coordinate(
                latitude: locationResponse.latitude,
                longitude: locationResponse.longitude
            )

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = isoFormatter.date(from: locationResponse.timestamp) ?? Date()

            return PatientLocation(
                coordinate: coordinate,
                timestamp: timestamp
            )
        } catch {
            print("[LocationAPIService] Failed to fetch location: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchSafeZones() async -> [SafeZone] {
        guard let url = URL(string: "\(baseURL)/safezones/\(patientId)") else { return [] }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            let responses = try JSONDecoder().decode([SafeZoneResponse].self, from: data)
            return responses.compactMap { r in
                guard let uuid = UUID(uuidString: r.id) else { return nil }
                return SafeZone(
                    id: uuid,
                    name: r.name,
                    center: Coordinate(latitude: r.centerLatitude, longitude: r.centerLongitude),
                    radiusMeters: r.radiusMeters,
                    durationMinutes: r.durationMinutes ?? 15,
                    isEnabled: r.isEnabled
                )
            }
        } catch {
            print("[LocationAPIService] Failed to fetch safe zones: \(error.localizedDescription)")
            return []
        }
    }

    func createSafeZone(_ zone: SafeZone) async -> Bool {
        guard let url = URL(string: "\(baseURL)/safezones") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "patientId": patientId,
            "name": zone.name,
            "centerLatitude": zone.center.latitude,
            "centerLongitude": zone.center.longitude,
            "radiusMeters": zone.radiusMeters,
            "durationMinutes": zone.durationMinutes
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 201
        } catch {
            print("[LocationAPIService] Failed to create safe zone: \(error.localizedDescription)")
            return false
        }
    }

    func updateSafeZone(_ zone: SafeZone) async -> Bool {
        guard let url = URL(string: "\(baseURL)/safezones/\(zone.id.uuidString)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": zone.name,
            "centerLatitude": zone.center.latitude,
            "centerLongitude": zone.center.longitude,
            "radiusMeters": zone.radiusMeters,
            "durationMinutes": zone.durationMinutes,
            "isEnabled": zone.isEnabled
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[LocationAPIService] Failed to update safe zone: \(error.localizedDescription)")
            return false
        }
    }

    func deleteSafeZone(id: UUID) async -> Bool {
        guard let url = URL(string: "\(baseURL)/safezones/\(id.uuidString)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[LocationAPIService] Failed to delete safe zone: \(error.localizedDescription)")
            return false
        }
    }
}
