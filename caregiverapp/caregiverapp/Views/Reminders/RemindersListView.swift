//
//  RemindersListView.swift
//  caregiverapp
//

import SwiftUI

struct RemindersListView: View {
    @State private var viewModel: RemindersViewModel
    @State private var showingAddReminder = false

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: RemindersViewModel(dataProvider: dataProvider))
    }

    var body: some View {
        List {
            if !viewModel.overdueReminders.isEmpty {
                Section { ForEach(viewModel.overdueReminders) { reminder in ReminderListRow(reminder: reminder, onComplete: { viewModel.markComplete(reminder) }, onSnooze: { viewModel.snooze(reminder, minutes: 15) }, onDelete: { viewModel.deleteReminder(reminder) }) } } header: { Label("Overdue", systemImage: "exclamationmark.circle.fill").foregroundStyle(.red) }
            }
            Section("Upcoming") {
                if viewModel.upcomingReminders.isEmpty { Text("No upcoming reminders").foregroundStyle(.secondary) }
                else { ForEach(viewModel.upcomingReminders) { reminder in ReminderListRow(reminder: reminder, onComplete: { viewModel.markComplete(reminder) }, onSnooze: { viewModel.snooze(reminder, minutes: 15) }, onDelete: { viewModel.deleteReminder(reminder) }) } }
            }
            if !viewModel.completedToday.isEmpty {
                Section("Completed Today") { ForEach(viewModel.completedToday) { reminder in ReminderListRow(reminder: reminder, onComplete: {}, onSnooze: nil, onDelete: { viewModel.deleteReminder(reminder) }) } }
            }
            Section("Quick Add") { quickAddButtons }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reminders")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: { showingAddReminder = true }) { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingAddReminder) { AddReminderSheet(viewModel: viewModel) }
        .onAppear { viewModel.onAppear() }
    }

    private var quickAddButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickAddButton(icon: "pills.fill", title: "Medication", color: .red) { showingAddReminder = true }
            QuickAddButton(icon: "drop.fill", title: "Hydration", color: .blue) { viewModel.addHydrationReminder(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()) }
            QuickAddButton(icon: "figure.walk", title: "Activity", color: .green) { showingAddReminder = true }
            QuickAddButton(icon: "calendar", title: "Appointment", color: .purple) { showingAddReminder = true }
        }.padding(.vertical, 8)
    }
}

struct ReminderListRow: View {
    let reminder: Reminder; let onComplete: () -> Void; let onSnooze: (() -> Void)?; let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onComplete) { Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(reminder.isCompleted ? .green : .secondary) }.buttonStyle(.plain)
            Image(systemName: reminder.type.icon).foregroundStyle(reminder.type.color).frame(width: 28, height: 28).background(reminder.type.color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title).font(.subheadline).strikethrough(reminder.isCompleted).foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                HStack(spacing: 4) { Text(reminder.timeString).font(.caption).foregroundStyle(reminder.isOverdue ? .red : .secondary); if reminder.repeatSchedule != .once { Text("- \(reminder.repeatSchedule.displayName)").font(.caption).foregroundStyle(.secondary) } }
                if let notes = reminder.notes { Text(notes).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
            }
            Spacer()
            if reminder.sendToWatch { Image(systemName: "applewatch").font(.caption).foregroundStyle(.secondary) }
        }
        .swipeActions(edge: .trailing) { Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }; if let onSnooze = onSnooze, !reminder.isCompleted { Button(action: onSnooze) { Label("Snooze", systemImage: "clock") }.tint(.orange) } }
        .swipeActions(edge: .leading) { if !reminder.isCompleted { Button(action: onComplete) { Label("Complete", systemImage: "checkmark") }.tint(.green) } }
    }
}

struct QuickAddButton: View {
    let icon: String; let title: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) { HStack { Image(systemName: icon).foregroundStyle(color); Text(title).font(.subheadline) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
    }
}

struct AddReminderSheet: View {
    let viewModel: RemindersViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var notes = ""; @State private var selectedType: ReminderType = .medication; @State private var scheduledTime = Date(); @State private var repeatSchedule: RepeatSchedule = .daily; @State private var sendToWatch = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") { TextField("Title", text: $title); Picker("Type", selection: $selectedType) { ForEach(ReminderType.allCases, id: \.self) { Label($0.displayName, systemImage: $0.icon).tag($0) } }; TextField("Notes (optional)", text: $notes) }
                Section("Schedule") { DatePicker("Time", selection: $scheduledTime, displayedComponents: [.hourAndMinute]); Picker("Repeat", selection: $repeatSchedule) { Text("Once").tag(RepeatSchedule.once); Text("Daily").tag(RepeatSchedule.daily); Text("Weekly").tag(RepeatSchedule.weekly) } }
                Section { Toggle("Send to Watch", isOn: $sendToWatch) } footer: { Text("When enabled, the patient will receive a haptic notification on their Apple Watch.") }
            }
            .navigationTitle("New Reminder").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { viewModel.addReminder(type: selectedType, title: title, notes: notes.isEmpty ? nil : notes, scheduledTime: scheduledTime, repeatSchedule: repeatSchedule, sendToWatch: sendToWatch); dismiss() }.disabled(title.isEmpty) }
            }
        }
    }
}
