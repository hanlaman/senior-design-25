//
//  SessionRow.swift
//  reMIND Watch App
//
//  Row component for displaying a conversation session in a list
//

import SwiftUI

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
