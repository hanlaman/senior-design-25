//
//  ServerSessionDetailView.swift
//  reMIND Watch App
//
//  Detail view showing conversation summary with access to full transcript
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
    @State private var showingTranscript = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let session = session {
                summaryView(session)
            }
        }
        .navigationTitle(session?.displayText ?? "Conversation")
        .sheet(isPresented: $showingTranscript) {
            if let session = session {
                ConversationTranscriptView(
                    messages: session.messages,
                    title: "Transcript"
                )
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
        do {
            try await ConversationFetchService.shared.deleteSession(sessionId: sessionId)
            WKInterfaceDevice.current().play(.success)
            dismiss()
        } catch {
            AppLogger.general.error("Failed to delete session: \(error.localizedDescription)")
            WKInterfaceDevice.current().play(.failure)
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Summary View

    private func summaryView(_ session: ServerConversationSessionDetail) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Summary", systemImage: "text.quote")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    if let summary = session.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No summary available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)

                Divider()

                // Action buttons
                VStack(spacing: 12) {
                    // Transcript button
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        showingTranscript = true
                    } label: {
                        HStack {
                            Image(systemName: "text.bubble")
                            Text("Transcript")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    // Delete button
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(.vertical, 8)
        }
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

}

// MARK: - Helper Extensions

extension ServerConversationSessionDetail {
    var displayText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startTime, relativeTo: Date())
    }
}
