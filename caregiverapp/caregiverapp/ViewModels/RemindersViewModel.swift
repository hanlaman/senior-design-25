//
//  RemindersViewModel.swift
//  caregiverapp
//

import Foundation
import Combine

@MainActor
@Observable
final class RemindersViewModel {
    private(set) var reminders: [Reminder] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    var upcomingReminders: [Reminder] { reminders.filter { !$0.isCompleted && $0.isEnabled }.sorted { $0.scheduledTime < $1.scheduledTime } }
    var overdueReminders: [Reminder] { reminders.filter { $0.isOverdue && $0.isEnabled } }
    var completedToday: [Reminder] {
        let today = Calendar.current.startOfDay(for: Date())
        return reminders.filter { guard let completedAt = $0.completedAt else { return false }; return Calendar.current.isDate(completedAt, inSameDayAs: today) }
    }
    var medicationReminders: [Reminder] { reminders.filter { $0.type == .medication } }

    private let dataProvider: PatientDataProvider
    private var cancellables = Set<AnyCancellable>()

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.remindersPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.reminders = $0 }.store(in: &cancellables)
    }

    func onAppear() { reminders = dataProvider.reminders }

    func addReminder(type: ReminderType, title: String, notes: String?, scheduledTime: Date, repeatSchedule: RepeatSchedule, sendToWatch: Bool) {
        let reminder = Reminder(type: type, title: title, notes: notes, scheduledTime: scheduledTime, repeatSchedule: repeatSchedule, sendToWatch: sendToWatch)
        Task { isLoading = true; defer { isLoading = false }; try? await dataProvider.addReminder(reminder) }
    }

    func updateReminder(_ reminder: Reminder) { Task { try? await dataProvider.updateReminder(reminder) } }
    func deleteReminder(_ reminder: Reminder) { Task { try? await dataProvider.deleteReminder(id: reminder.id) } }
    func markComplete(_ reminder: Reminder) { Task { try? await dataProvider.markReminderComplete(id: reminder.id) } }

    func toggleEnabled(_ reminder: Reminder) {
        var updated = reminder
        updated.isEnabled.toggle()
        updateReminder(updated)
    }

    func snooze(_ reminder: Reminder, minutes: Int) {
        var updated = reminder
        updated.scheduledTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        updateReminder(updated)
    }

    func addMedicationReminder(name: String, time: Date, notes: String? = nil) { addReminder(type: .medication, title: name, notes: notes, scheduledTime: time, repeatSchedule: .daily, sendToWatch: true) }
    func addActivityReminder(title: String, time: Date) { addReminder(type: .activity, title: title, notes: nil, scheduledTime: time, repeatSchedule: .daily, sendToWatch: true) }
    func addHydrationReminder(time: Date) { addReminder(type: .hydration, title: "Drink Water", notes: nil, scheduledTime: time, repeatSchedule: .daily, sendToWatch: true) }
}
