//
//  AddEditFactSheet.swift
//  caregiverapp
//
//  Sheet for adding or editing a patient fact.
//

import SwiftUI

struct AddEditFactSheet: View {
    enum Mode {
        case add
        case edit(PatientFact)

        var title: String {
            switch self {
            case .add: return "Add Fact"
            case .edit: return "Edit Fact"
            }
        }
    }

    let mode: Mode
    let onSave: (PatientFact) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: FactCategory
    @State private var label: String
    @State private var value: String

    private var existingId: UUID?

    init(mode: Mode, onSave: @escaping (PatientFact) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .add:
            _category = State(wrappedValue: .personal)
            _label = State(wrappedValue: "")
            _value = State(wrappedValue: "")
            existingId = nil
        case .edit(let fact):
            _category = State(wrappedValue: fact.category)
            _label = State(wrappedValue: fact.label)
            _value = State(wrappedValue: fact.value)
            existingId = fact.id
        }
    }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty &&
        !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(FactCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Details") {
                    TextField("Label", text: $label, prompt: Text("e.g., Spouse's Name"))
                    TextField("Value", text: $value, prompt: Text("e.g., Margaret"), axis: .vertical)
                        .lineLimit(1...5)
                }

                Section {
                    suggestionsForCategory
                } header: {
                    Text("Suggestions")
                } footer: {
                    Text("Tap a suggestion to fill in the label.")
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let fact = PatientFact(
                            id: existingId ?? UUID(),
                            category: category,
                            label: label.trimmingCharacters(in: .whitespaces),
                            value: value.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(fact)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsForCategory: some View {
        let suggestions = Self.suggestions[category] ?? []
        ForEach(suggestions, id: \.self) { suggestion in
            Button(suggestion) {
                label = suggestion
            }
            .foregroundStyle(.primary)
        }
    }

    static let suggestions: [FactCategory: [String]] = [
        .personal: ["Full Name", "Nickname", "Date of Birth", "Hometown", "Former Occupation", "Languages Spoken"],
        .family: ["Spouse", "Son/Daughter", "Grandchild", "Sibling", "Pet"],
        .medical: ["Diagnosis", "Medication", "Allergy", "Doctor's Name", "Pharmacy"],
        .routine: ["Morning Routine", "Mealtime", "Bedtime", "Exercise Habit", "Favorite Walk Route"],
        .preference: ["Favorite Food", "Favorite Music", "Favorite TV Show", "Hobbies", "Dislikes"],
        .other: ["Important Date", "Religious Practice", "Cultural Background", "Special Notes"],
    ]
}

#Preview {
    AddEditFactSheet(mode: .add) { fact in
        print("Saved: \(fact)")
    }
}
