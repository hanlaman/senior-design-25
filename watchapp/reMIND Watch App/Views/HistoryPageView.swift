//
//  HistoryPageView.swift
//  reMIND Watch App
//
//  Created by Claude Code
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

// MARK: - Session Row

struct SessionRow: View {
    let session: ConversationSession

    var body: some View {
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
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: ConversationSession
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        List(session.messages) { message in
            MessageRow(message: message)
        }
        .listStyle(.carousel)
        .navigationTitle(session.displayText)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .alert("Delete Conversation?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                WKInterfaceDevice.current().play(.click)
                ConversationHistoryManager.shared.deleteSession(session.id)
                dismiss()
            }
        } message: {
            Text("This conversation will be permanently deleted.")
        }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: ConversationMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Role icon
            Image(systemName: message.role == .user ? "person.fill" : "waveform")
                .foregroundColor(message.role == .user ? .blue : .green)
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
            ),
            ConversationMessage(
                id: "msg3",
                role: .user,
                content: "Should I bring an umbrella?",
                timestamp: Date().addingTimeInterval(-3580),
                sessionId: "test-session"
            ),
            ConversationMessage(
                id: "msg4",
                role: .assistant,
                content: "No need for an umbrella today. The forecast shows clear skies all day.",
                timestamp: Date().addingTimeInterval(-3570),
                sessionId: "test-session"
            )
        ]
    )

    return SessionDetailView(session: mockSession)
}
