//
//  QuickActionButton.swift
//  caregiverapp
//

import SwiftUI

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(.white).frame(width: 50, height: 50).background(color).clipShape(Circle())
                Text(title).font(.caption).foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionRow: View {
    var onCall: () -> Void = {}
    var onMessage: () -> Void = {}
    var onVideo: () -> Void = {}
    var onAlert: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "phone.fill", title: "Call", color: .green, action: onCall)
            QuickActionButton(icon: "message.fill", title: "Message", color: .blue, action: onMessage)
            QuickActionButton(icon: "video.fill", title: "Video", color: .purple, action: onVideo)
            QuickActionButton(icon: "bell.fill", title: "Alert", color: .orange, action: onAlert)
        }
    }
}
