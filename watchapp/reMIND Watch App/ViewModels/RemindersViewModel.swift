//
//  RemindersViewModel.swift
//  reMIND Watch App
//
//  Manages reminder state for the watch reminders page.
//

import Foundation
import Combine
import os

@MainActor
class RemindersViewModel: ObservableObject {
    @Published var reminders: [WatchReminder] = []
    @Published var isLoading = false

    private let reminderService = ReminderService.shared
    private let actionService = ReminderActionService()
    private var cancellables = Set<AnyCancellable>()

    var upcomingReminders: [WatchReminder] {
        reminders.filter { !$0.isCompleted }.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    var completedReminders: [WatchReminder] {
        reminders.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    init() {
        listenForSyncNotifications()
    }

    private func listenForSyncNotifications() {
        NotificationCenter.default.publisher(for: .remindersDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        reminders = await reminderService.fetchReminders()
    }

    func markComplete(_ reminder: WatchReminder) async {
        await actionService.markComplete(reminderId: reminder.id)
        await refresh()
    }

    func snooze(_ reminder: WatchReminder, minutes: Int = 15) async {
        await actionService.snooze(reminderId: reminder.id, minutes: minutes)
        await refresh()
    }

}
