//
//  reMINDApp.swift
//  reMIND Watch App
//
//  Created by Spencer Will on 1/22/26.
//

import SwiftUI
import WatchKit
import UserNotifications
import os

extension Notification.Name {
    static let remindersDidChange = Notification.Name("remindersDidChange")
}

@main
struct reMIND_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    private let deviceTokenService = DeviceTokenService()
    private let reminderActionService = ReminderActionService()

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                AppLogger.general.info("Notification authorization granted")
            } else if let error = error {
                AppLogger.logError(error, category: AppLogger.general, context: "Notification authorization failed")
            }
        }

        // Register for remote notifications
        WKExtension.shared().registerForRemoteNotifications()

        // Register actionable notification category
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Done",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 15m",
            options: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])

        // Re-register cached device token on restart
        Task {
            await deviceTokenService.reregisterCachedToken()
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        Task {
            await deviceTokenService.registerToken(deviceToken)
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        AppLogger.logError(error, category: AppLogger.general, context: "Failed to register for remote notifications")
    }

    // Handle silent push notifications (content-available: 1) for two-way sync
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult {
        AppLogger.general.debug("Received sync push: \(userInfo)")
        NotificationCenter.default.post(name: .remindersDidChange, object: nil, userInfo: userInfo)
        return .newData
    }

    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let reminderId = userInfo["reminderId"] as? String else {
            completionHandler()
            return
        }

        Task {
            switch response.actionIdentifier {
            case "COMPLETE":
                await reminderActionService.markComplete(reminderId: reminderId)
            case "SNOOZE":
                await reminderActionService.snooze(reminderId: reminderId)
            default:
                break
            }
            completionHandler()
        }
    }

    // Show notifications while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
