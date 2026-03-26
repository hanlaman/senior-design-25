//
//  PatientFactsView.swift
//  caregiverapp
//
//  Displays patient facts grouped by category. Caregivers can add, edit,
//  and delete facts. These facts are sent to the backend and used as
//  context for the watch voice assistant.
//

import SwiftUI

struct PatientFactsView: View {
    @State private var viewModel = PatientFactsViewModel()
    @State private var showingAddSheet = false
    @State private var editingFact: PatientFact?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.facts.isEmpty {
                ProgressView("Loading facts...")
            } else if viewModel.facts.isEmpty {
                emptyState
            } else {
                factsList
            }
        }
        .navigationTitle("Patient Info")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditFactSheet(mode: .add) { fact in
                Task { await viewModel.addFact(fact) }
            }
        }
        .sheet(item: $editingFact) { fact in
            AddEditFactSheet(mode: .edit(fact)) { updatedFact in
                Task { await viewModel.updateFact(updatedFact) }
            }
        }
        .task {
            await viewModel.loadFacts()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Patient Information")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Add facts about your patient to help the voice assistant provide personalized support.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: { showingAddSheet = true }) {
                Label("Add First Fact", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    private var factsList: some View {
        List {
            ForEach(viewModel.groupedFacts, id: \.category) { group in
                Section {
                    ForEach(group.facts) { fact in
                        FactRow(fact: fact)
                            .contentShape(Rectangle())
                            .onTapGesture { editingFact = fact }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteFact(id: fact.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Label(group.category.displayName, systemImage: group.category.icon)
                }
            }
        }
        .refreshable {
            await viewModel.loadFacts()
        }
    }
}

struct FactRow: View {
    let fact: PatientFact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fact.label)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(fact.value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        PatientFactsView()
    }
}
