//
//  ConversationTranscriptView.swift
//  reMIND Watch App
//
//  Displays the full message transcript for a conversation as a modal sheet
//

import SwiftUI

struct ConversationTranscriptView: View {
    let messages: [ServerConversationMessage]
    let title: String

    var body: some View {
        List(messages) { message in
            messageRow(message)
        }
        .listStyle(.carousel)
    }

    // MARK: - Message Row

    private func messageRow(_ message: ServerConversationMessage) -> some View {
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
}
