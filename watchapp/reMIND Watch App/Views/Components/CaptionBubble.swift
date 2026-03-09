//
//  CaptionBubble.swift
//  reMIND Watch App
//
//  Individual caption bubble component for transcription display
//

import SwiftUI

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
