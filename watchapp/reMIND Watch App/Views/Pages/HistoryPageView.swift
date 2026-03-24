//
//  HistoryPageView.swift
//  reMIND Watch App
//
//  Main history page view displaying conversation sessions fetched from backend
//

import SwiftUI
import WatchKit
import os

struct HistoryPageView: View {
    @Binding var currentPage: ContentView.NavigationPage?

    @State private var sessions: [ServerConversationSession] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    backButton
                }
            }
        }
        .task {
            await fetchSessions()
        }
    }

    // MARK: - Data Fetching

    private func fetchSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            sessions = try await ConversationFetchService.shared.fetchSessions()
        } catch {
            AppLogger.general.error("Failed to fetch sessions: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(destination: ServerSessionDetailView(sessionId: session.id)) {
                    serverSessionRow(session)
                }
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await fetchSessions()
        }
    }

    private func serverSessionRow(_ session: ServerConversationSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayText)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("\(session.messageCount) message\(session.messageCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
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
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Unable to Load")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                Task {
                    await fetchSessions()
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Conversations")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Start a conversation to see history")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toolbar

    private var backButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            currentPage = .voice
        } label: {
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.blue)
        }
    }
}
