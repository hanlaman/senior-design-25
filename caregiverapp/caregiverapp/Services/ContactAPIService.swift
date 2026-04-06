//
//  ContactAPIService.swift
//  caregiverapp
//
//  Syncs caregiver and patient phone numbers with the backend API.
//

import Foundation

@MainActor
final class ContactAPIService {
    private let baseURL: String
    private let patientId: String

    init(baseURL: String = BuildConfiguration.apiBaseURL, patientId: String = BuildConfiguration.patientId) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func upsertContact(role: String, name: String, phoneNumber: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/contacts") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "patientId": patientId,
            "role": role,
            "name": name,
            "phoneNumber": phoneNumber,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[ContactAPIService] Failed to upsert contact: \(error.localizedDescription)")
            return false
        }
    }

    struct ContactResponse: Codable {
        let id: String
        let patientId: String
        let role: String
        let name: String
        let phoneNumber: String
    }

    func fetchContacts() async -> [ContactResponse] {
        guard let url = URL(string: "\(baseURL)/contacts/\(patientId)") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            return try JSONDecoder().decode([ContactResponse].self, from: data)
        } catch {
            print("[ContactAPIService] Failed to fetch contacts: \(error.localizedDescription)")
            return []
        }
    }
}
