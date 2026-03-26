//
//  PatientFactsViewModel.swift
//  caregiverapp
//
//  Manages patient facts CRUD operations with the backend API.
//

import Foundation

@MainActor
@Observable
final class PatientFactsViewModel {
    private(set) var facts: [PatientFact] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let api = PatientFactsAPIService()

    var groupedFacts: [(category: FactCategory, facts: [PatientFact])] {
        let grouped = Dictionary(grouping: facts, by: { $0.category })
        return FactCategory.allCases
            .compactMap { category in
                guard let items = grouped[category], !items.isEmpty else { return nil }
                return (category: category, facts: items)
            }
    }

    func loadFacts() async {
        isLoading = true
        facts = await api.fetchFacts()
        isLoading = false
    }

    func addFact(_ fact: PatientFact) async {
        let success = await api.createFact(fact)
        if success {
            facts = await api.fetchFacts()
        } else {
            // Fallback to local-only if API unavailable
            facts.append(fact)
        }
    }

    func updateFact(_ fact: PatientFact) async {
        let success = await api.updateFact(fact)
        if success {
            facts = await api.fetchFacts()
        } else if let index = facts.firstIndex(where: { $0.id == fact.id }) {
            facts[index] = fact
        }
    }

    func deleteFact(id: UUID) async {
        let success = await api.deleteFact(id: id)
        if success {
            facts = await api.fetchFacts()
        } else {
            facts.removeAll { $0.id == id }
        }
    }
}
