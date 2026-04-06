//
//  SettingsSheet.swift
//  caregiverapp
//
//  Settings sheet with account options including sign out.
//

import SwiftUI

struct SettingsSheet: View {
    var authViewModel: AuthViewModel?

    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutConfirmation = false

    @AppStorage("caregiverPhoneNumber") private var caregiverPhone = ""
    @AppStorage("patientPhoneNumber") private var patientPhone = ""

    private let contactAPI = ContactAPIService()

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    if let user = authViewModel?.currentUser {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Account")
                }

                // Phone Numbers Section
                Section {
                    HStack {
                        Label("Caregiver", systemImage: "person.fill")
                            .frame(width: 130, alignment: .leading)
                        TextField("Phone number", text: $caregiverPhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Patient", systemImage: "heart.fill")
                            .frame(width: 130, alignment: .leading)
                        TextField("Phone number", text: $patientPhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Phone Numbers")
                } footer: {
                    Text("Used for quick call, message, and FaceTime actions from the dashboard.")
                }

                // Settings Section
                Section {
                    NavigationLink {
                        Text("Notification settings coming soon")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }

                    NavigationLink {
                        Text("Privacy settings coming soon")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Preferences")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                    .confirmationDialog(
                        "Sign Out",
                        isPresented: $showingSignOutConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await authViewModel?.signOut()
                                dismiss()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to sign out?")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        syncContacts()
                        dismiss()
                    }
                }
            }
            .task {
                let contacts = await contactAPI.fetchContacts()
                for contact in contacts {
                    switch contact.role {
                    case "caregiver":
                        if caregiverPhone.isEmpty { caregiverPhone = contact.phoneNumber }
                    case "patient":
                        if patientPhone.isEmpty { patientPhone = contact.phoneNumber }
                    default:
                        break
                    }
                }
            }
        }
    }

    private func syncContacts() {
        let caregiver = caregiverPhone
        let patient = patientPhone
        Task {
            if !caregiver.isEmpty {
                _ = await contactAPI.upsertContact(role: "caregiver", name: "Caregiver", phoneNumber: caregiver)
            }
            if !patient.isEmpty {
                _ = await contactAPI.upsertContact(role: "patient", name: "Patient", phoneNumber: patient)
            }
        }
    }
}

#Preview {
    SettingsSheet(authViewModel: nil)
}
