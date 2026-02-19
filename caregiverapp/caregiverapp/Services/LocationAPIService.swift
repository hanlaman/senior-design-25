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
}
