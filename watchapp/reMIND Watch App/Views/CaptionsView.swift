//
//  CaptionsView.swift
//  reMIND Watch App
//
//  Scrollable view displaying live transcription captions
//

import SwiftUI

/// Scrollable captions view with chat bubble layout
struct CaptionsView: View {
    @ObservedObject var transcriptionManager: TranscriptionManager

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(transcriptionManager.sortedMessages) { message in
                        CaptionBubble(
                            message: message,
                            isActiveAgent: message.itemId == transcriptionManager.activeAgentItemId,
                            revealProgress: transcriptionManager.revealProgress
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 35)     // Space for top toolbar
                .padding(.bottom, 35)  // Space for bottom toolbar
            }
            .onChange(of: transcriptionManager.messages.count) { _, _ in
                // Auto-scroll to latest message
                if let lastMessage = transcriptionManager.sortedMessages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: transcriptionManager.revealProgress) { _, _ in
                // Also scroll when reveal progress updates (keeps current message visible)
                if let lastMessage = transcriptionManager.sortedMessages.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// Individual caption bubble with colored background (full width)
struct CaptionBubble: View {
    let message: TranscriptionMessage
    let isActiveAgent: Bool
    let revealProgress: Double

    var body: some View {
        Text(displayText)
            .font(.caption2)
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(bubbleColor)
            )
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : .green.opacity(0.8)
    }

    /// Text to display, with typewriter effect for active agent messages
    private var displayText: String {
        guard message.role == .agent else {
            return message.displayText
        }

        // If message is complete, show full displayText
        if message.isComplete {
            return message.displayText
        }

        // For active agent message, apply typewriter reveal
        if isActiveAgent {
            let text = message.text  // Use progressive text during playback
            guard !text.isEmpty else { return "" }

            let revealedCount = Int(Double(text.count) * revealProgress)
            return String(text.prefix(max(1, revealedCount)))
        }

        // Not the active message but not complete - show full text
        return message.displayText
    }
}

// MARK: - Preview

#Preview {
    CaptionsView(transcriptionManager: TranscriptionManager())
        .background(Color.black)
}
