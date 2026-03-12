//
//  RemindersPageView.swift
//  reMIND Watch App
//
//  Displays upcoming and completed reminders on the watch.
//

import SwiftUI
import WatchKit

struct RemindersPageView: View {
    @ObservedObject var viewModel: RemindersViewModel
    @Binding var currentPage: ContentView.NavigationPage?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.reminders.isEmpty {
                ProgressView("Loading...")
            } else if viewModel.reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No Reminders")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    if !viewModel.upcomingReminders.isEmpty {
                        Section("Upcoming") {
                            ForEach(viewModel.upcomingReminders) { reminder in
                                ReminderRow(reminder: reminder) {
                                    Task { await viewModel.markComplete(reminder) }
                                }
                            }
                        }
                    }

                    if !viewModel.completedReminders.isEmpty {
                        Section("Completed") {
                            ForEach(viewModel.completedReminders) { reminder in
                                ReminderRow(reminder: reminder, onComplete: nil)
                            }
                        }
                    }
                }
                .listStyle(.carousel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    currentPage = .voice
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
}

struct ReminderRow: View {
    let reminder: WatchReminder
    let onComplete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: reminder.typeIcon)
                    .foregroundColor(reminder.isOverdue ? .red : .accentColor)
                    .font(.caption)

                Text(reminder.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(reminder.isCompleted)
                    .foregroundColor(reminder.isCompleted ? .gray : .primary)
            }

            Text(reminder.dateTimeString)
                .font(.caption2)
                .foregroundColor(reminder.isOverdue ? .red : .secondary)

            HStack(spacing: 4) {
                Text(reminder.repeatLabel)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)

                if reminder.isOverdue {
                    Text("Overdue")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }

            if let notes = reminder.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if !reminder.isCompleted, let onComplete = onComplete {
                Button {
                    WKInterfaceDevice.current().play(.success)
                    onComplete()
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }
}
