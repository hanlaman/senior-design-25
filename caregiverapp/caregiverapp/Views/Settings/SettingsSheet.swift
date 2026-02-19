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
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsSheet(authViewModel: nil)
}
