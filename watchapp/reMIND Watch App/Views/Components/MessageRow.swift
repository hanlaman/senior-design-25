//
//  MessageRow.swift
//  reMIND Watch App
//
//  Row component for displaying a conversation message
//

import SwiftUI

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
