//
//  PatientFactsAPIService.swift
//  caregiverapp
//
//  Fetches and manages patient facts via the backend API.
//

import Foundation

struct PatientFactResponse: Codable {
    let id: String
    let patientId: String
    let category: String
    let label: String
    let value: String
    let createdAt: String
    let updatedAt: String
}

@MainActor
final class PatientFactsAPIService {
    private let baseURL: String
    private let patientId: String

    init(baseURL: String = "http://localhost:3000", patientId: String = "demo-patient-1") {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func fetchFacts() async -> [PatientFact] {
        guard let url = URL(string: "\(baseURL)/patient-facts/\(patientId)") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            let responses = try JSONDecoder().decode([PatientFactResponse].self, from: data)
            return responses.compactMap { mapToFact($0) }
        } catch {
            print("[PatientFactsAPIService] Failed to fetch facts: \(error.localizedDescription)")
            return []
        }
    }

    func createFact(_ fact: PatientFact) async -> Bool {
        guard let url = URL(string: "\(baseURL)/patient-facts") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "patientId": patientId,
            "category": fact.category.rawValue,
            "label": fact.label,
            "value": fact.value
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 201
        } catch {
            print("[PatientFactsAPIService] Failed to create fact: \(error.localizedDescription)")
            return false
        }
    }

    func updateFact(_ fact: PatientFact) async -> Bool {
        guard let url = URL(string: "\(baseURL)/patient-facts/\(fact.id.uuidString)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "category": fact.category.rawValue,
            "label": fact.label,
            "value": fact.value
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[PatientFactsAPIService] Failed to update fact: \(error.localizedDescription)")
            return false
        }
    }

    func deleteFact(id: UUID) async -> Bool {
        guard let url = URL(string: "\(baseURL)/patient-facts/\(id.uuidString)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[PatientFactsAPIService] Failed to delete fact: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helpers

    private func mapToFact(_ r: PatientFactResponse) -> PatientFact? {
        guard let uuid = UUID(uuidString: r.id),
              let category = FactCategory(rawValue: r.category) else { return nil }

        return PatientFact(
            id: uuid,
            category: category,
            label: r.label,
            value: r.value
        )
    }
}
