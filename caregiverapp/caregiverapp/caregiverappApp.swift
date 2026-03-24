//
//  caregiverappApp.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: THE APP ENTRY POINT
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  This file is the starting point of your iOS app. Every SwiftUI app needs
//  exactly one type (struct/class) marked with @main to tell iOS where to begin.
//

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ IMPORT STATEMENTS                                                           │
// │                                                                             │
// │ 'import' brings in external frameworks/libraries. SwiftUI is Apple's       │
// │ modern UI framework that provides View, @State, etc.                        │
// └─────────────────────────────────────────────────────────────────────────────┘
import SwiftUI
import UserNotifications

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ @main ATTRIBUTE                                                             │
// │                                                                             │
// │ This attribute marks the entry point of your app. When iOS launches your   │
// │ app, it looks for @main and creates an instance of this struct.            │
// │ You can only have ONE @main in your entire app.                            │
// └─────────────────────────────────────────────────────────────────────────────┘
@main

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ STRUCT vs CLASS                                                             │
// │                                                                             │
// │ Swift has two main ways to define custom types:                            │
// │                                                                             │
// │ STRUCT (Value Type):                                                        │
// │   - Copied when assigned to a new variable                                  │
// │   - Preferred in SwiftUI for Views and simple data                         │
// │   - Immutable by default (use 'var' to make properties mutable)            │
// │   - No inheritance (but can conform to protocols)                           │
// │                                                                             │
// │ CLASS (Reference Type):                                                     │
// │   - Passed by reference (multiple variables point to same object)          │
// │   - Used for ViewModels and services that need to be shared                │
// │   - Supports inheritance                                                    │
// │   - Can use deinit for cleanup                                             │
// │                                                                             │
// │ SwiftUI Views are ALWAYS structs because:                                  │
// │   1. They're lightweight and fast to create/destroy                        │
// │   2. SwiftUI recreates views frequently during UI updates                  │
// │   3. Value semantics make state changes predictable                        │
// └─────────────────────────────────────────────────────────────────────────────┘
struct caregiverappApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @State PROPERTY WRAPPER                                                 │
    // │                                                                         │
    // │ Property wrappers add special behavior to properties. @State tells     │
    // │ SwiftUI: "Watch this value. When it changes, update the UI."           │
    // │                                                                         │
    // │ @State rules:                                                           │
    // │   - Use for simple value types owned by THIS view                       │
    // │   - Always mark as 'private' (only this view should modify it)         │
    // │   - SwiftUI manages the storage, so the struct can stay immutable      │
    // │                                                                         │
    // │ Other property wrappers you'll see:                                     │
    // │   @Binding     - Reference to @State owned by parent view              │
    // │   @StateObject - For ObservableObject classes (view creates it)        │
    // │   @ObservedObject - For ObservableObject passed from parent            │
    // │   @EnvironmentObject - For shared objects in the view hierarchy        │
    // │   @Published   - In classes, triggers UI updates when changed          │
    // └─────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ PROTOCOLS (Like interfaces in other languages)                          │
    // │                                                                         │
    // │ 'PatientDataProvider' is a PROTOCOL - it defines a contract of what    │
    // │ methods/properties a type must have, without implementing them.        │
    // │                                                                         │
    // │ Here, the variable TYPE is the protocol, but the VALUE is a concrete   │
    // │ class (MockDataService). This is "programming to an interface" -       │
    // │ we can swap MockDataService for FirebaseDataService later without      │
    // │ changing any other code!                                               │
    // └─────────────────────────────────────────────────────────────────────────┘
    @State private var dataProvider: PatientDataProvider = MockDataService()

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ AUTHENTICATION                                                          │
    // │                                                                         │
    // │ AuthService handles user authentication with the backend API.          │
    // │ AuthViewModel manages auth state and exposes it to views.              │
    // │                                                                         │
    // │ The auth flow:                                                          │
    // │   1. App launches → check for stored session                            │
    // │   2. If no session → show login/signup screens                          │
    // │   3. If session exists → show main app                                  │
    // └─────────────────────────────────────────────────────────────────────────┘
    @State private var authService: AuthService = APIAuthService()
    @State private var authViewModel: AuthViewModel?

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED PROPERTY: body                                                 │
    // │                                                                         │
    // │ 'var body: some Scene' is a COMPUTED PROPERTY - it doesn't store a     │
    // │ value, it calculates and returns one each time it's accessed.          │
    // │                                                                         │
    // │ Syntax breakdown:                                                       │
    // │   var        - Declares a variable (required for computed properties)  │
    // │   body       - Property name (required by App protocol)                │
    // │   : some Scene - Return type using 'some' (opaque type)                │
    // │                                                                         │
    // │ 'some Scene' means: "Returns something that conforms to Scene,         │
    // │ but I won't specify exactly what type." This is an OPAQUE TYPE.        │
    // │ The compiler knows the concrete type, but it's hidden from callers.    │
    // └─────────────────────────────────────────────────────────────────────────┘
    var body: some Scene {

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ WindowGroup                                                         │
        // │                                                                     │
        // │ WindowGroup is a Scene that manages a window on iOS/macOS.         │
        // │ On iOS, this creates your main app window. On macOS/iPadOS,        │
        // │ it can create multiple windows.                                    │
        // │                                                                     │
        // │ The closure { } inside contains the ROOT VIEW of your app.         │
        // │ Everything inside this closure is what users see.                  │
        // └─────────────────────────────────────────────────────────────────────┘
        WindowGroup {
            // RootView handles showing auth screens or main content
            // based on authentication state
            if let authViewModel = authViewModel {
                RootView(authViewModel: authViewModel, dataProvider: dataProvider)
            } else {
                // Show loading while initializing
                ProgressView()
                    .task {
                        // Initialize the auth view model on first appear
                        authViewModel = AuthViewModel(authService: authService)
                    }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let remindersDidChange = Notification.Name("remindersDidChange")
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let deviceTokenService = DeviceTokenService.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("[AppDelegate] Notification authorization error: \(error.localizedDescription)")
            }
        }

        Task {
            await deviceTokenService.reregisterCachedToken()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await deviceTokenService.registerToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Show alert notifications even when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle silent push notifications (content-available: 1)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationCenter.default.post(name: .remindersDidChange, object: nil, userInfo: userInfo)
        completionHandler(.newData)
    }
}
