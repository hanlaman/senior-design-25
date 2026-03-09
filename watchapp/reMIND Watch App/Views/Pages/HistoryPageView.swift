//
//  HistoryPageView.swift
//  reMIND Watch App
//
//  Main history page view displaying conversation sessions
//

import SwiftUI
import WatchKit

struct HistoryPageView: View {
    @ObservedObject private var historyManager = ConversationHistoryManager.shared
    @Binding var currentPage: ContentView.NavigationPage?

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.history.sessions.isEmpty {
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
    }

    // MARK: - Session List

    private var sessionListView: some View {
        List {
            ForEach(historyManager.history.sessions.sorted(by: { $0.startTime > $1.startTime })) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRow(session: session)
                }
            }
        }
        .listStyle(.carousel)
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

// MARK: - Preview

#Preview {
    let mockSession = ConversationSession(
        id: "test-session",
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date(),
        messages: [
            ConversationMessage(
                id: "msg1",
                role: .user,
                content: "What's the weather like today?",
                timestamp: Date().addingTimeInterval(-3600),
                sessionId: "test-session"
            ),
            ConversationMessage(
                id: "msg2",
                role: .assistant,
                content: "It's 72 degrees and sunny outside.",
                timestamp: Date().addingTimeInterval(-3590),
                sessionId: "test-session"
            )
        ]
    )

    return SessionDetailView(session: mockSession)
}
