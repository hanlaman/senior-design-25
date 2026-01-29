//
//  ReminderRow.swift
//  caregiverapp
//

import SwiftUI

struct ReminderRow: View {
    let reminder: Reminder
    var onComplete: (() -> Void)?
    var onSnooze: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { onComplete?() }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(reminder.isCompleted ? .green : .secondary)
            }
            Image(systemName: reminder.type.icon).foregroundStyle(reminder.type.color).frame(width: 32, height: 32).background(reminder.type.color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title).font(.subheadline).fontWeight(.medium).strikethrough(reminder.isCompleted).foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                HStack(spacing: 4) {
                    Text(reminder.timeString).font(.caption).foregroundStyle(reminder.isOverdue ? .red : .secondary)
                    if reminder.isOverdue { Text("Overdue").font(.caption2).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(.red).clipShape(Capsule()) }
                    if reminder.repeatSchedule != .once { Image(systemName: "repeat").font(.caption2).foregroundStyle(.secondary) }
                }
                if let notes = reminder.notes, !notes.isEmpty { Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            if !reminder.isCompleted && onSnooze != nil { Button(action: { onSnooze?() }) { Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary) } }
        }
        .padding(.vertical, 8)
    }
}

struct ReminderCard: View {
    let reminder: Reminder
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.type.icon).font(.title3).foregroundStyle(reminder.type.color).frame(width: 44, height: 44).background(reminder.type.color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title).font(.subheadline).fontWeight(.medium)
                Text(reminder.timeString).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !reminder.isCompleted {
                Button(action: { onComplete?() }) { Image(systemName: "checkmark").font(.subheadline).fontWeight(.semibold).foregroundStyle(.white).frame(width: 32, height: 32).background(.green).clipShape(Circle()) }
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
