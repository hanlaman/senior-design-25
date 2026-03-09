//
//  SessionDetailView.swift
//  reMIND Watch App
//
//  Detail view for displaying messages in a conversation session
//

import SwiftUI
import WatchKit

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
