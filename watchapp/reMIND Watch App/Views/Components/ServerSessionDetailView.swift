//
//  ServerSessionDetailView.swift
//  reMIND Watch App
//
//  Detail view for displaying messages fetched from the backend server
//

import SwiftUI
import WatchKit
import os

struct ServerSessionDetailView: View {
    let sessionId: String

    @Environment(\.dismiss) private var dismiss
    @State private var session: ServerConversationSessionDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let session = session {
                messageListView(session)
            }
        }
        .navigationTitle(session?.displayText ?? "Conversation")
        .toolbar {
            if session != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    deleteButton
                }
            }
        }
        .alert("Delete Conversation?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSession()
                }
            }
        } message: {
            Text("This conversation will be permanently deleted.")
        }
        .task {
            await fetchSession()
        }
    }

    // MARK: - Data Fetching

    private func fetchSession() async {
        isLoading = true
        errorMessage = nil

        do {
            session = try await ConversationFetchService.shared.fetchSession(sessionId: sessionId)
        } catch {
            AppLogger.general.error("Failed to fetch session: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteSession() async {
        // TODO: Implement backend delete when needed
        // For now, just dismiss
        WKInterfaceDevice.current().play(.click)
        dismiss()
    }

    // MARK: - Message List

    private func messageListView(_ session: ServerConversationSessionDetail) -> some View {
        List(session.messages) { message in
            serverMessageRow(message)
        }
        .listStyle(.carousel)
    }

    private func serverMessageRow(_ message: ServerConversationMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Role icon
            Image(systemName: message.role == "user" ? "person.fill" : "waveform")
                .foregroundColor(message.role == "user" ? .blue : .green)
                .font(.title3)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.caption)
                    .lineLimit(nil)

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Error State

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Unable to Load")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await fetchSession()
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            showingDeleteAlert = true
        } label: {
            Image(systemName: "trash")
                .font(.title3)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Helper Extensions

extension ServerConversationSessionDetail {
    var displayText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startTime, relativeTo: Date())
    }
}
