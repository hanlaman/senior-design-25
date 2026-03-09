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
            .onChange(of: transcriptionManager.revealProgress) { oldValue, newValue in
                // Only scroll on significant progress changes (reduces animation frequency)
                // This helps reduce Simulator graphics warnings
                guard abs(newValue - oldValue) > 0.05 else { return }

                if let lastMessage = transcriptionManager.sortedMessages.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CaptionsView(transcriptionManager: TranscriptionManager())
        .background(Color.black)
}
