//
//  ContentView.swift
//  reMIND Watch App
//
//  Main view for voice assistant with vertical page navigation
//

import SwiftUI
import WatchKit
import AVFoundation
import os

struct ContentView: View {
    @StateObject private var viewModel = VoiceViewModel()
    @StateObject private var locationViewModel = LocationViewModel()
    @StateObject private var remindersViewModel = RemindersViewModel()
    @State private var currentPage: NavigationPage? = .voice
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasConnectedBeforeBackground = false

    enum NavigationPage: Int, CaseIterable, Hashable {
        case history = 0
        case voice = 1
        case reminders = 2
        case settings = 3
    }

    var body: some View {
        TabView(selection: $currentPage) {
            // History page (swipe left from voice page)
            // Wrapped in NavigationStack to enable drill-down navigation
            NavigationStack {
                HistoryPageView(currentPage: $currentPage)
            }
            .tag(NavigationPage.history as NavigationPage?)

            // Main voice page (center, default)
            // Wrapped in NavigationStack for consistent toolbar navigation
            NavigationStack {
                VoicePageView(viewModel: viewModel, currentPage: $currentPage)
            }
            .tag(NavigationPage.voice as NavigationPage?)

            // Reminders page (swipe right from voice page)
            NavigationStack {
                RemindersPageView(viewModel: remindersViewModel, currentPage: $currentPage)
            }
            .tag(NavigationPage.reminders as NavigationPage?)

            // Settings page (swipe right from reminders page)
            NavigationStack {
                SettingsPageView(viewModel: viewModel, locationViewModel: locationViewModel, currentPage: $currentPage)
            }
            .tag(NavigationPage.settings as NavigationPage?)
        }
        .tabViewStyle(.page)
        .ignoresSafeArea()
        .task {
            // Request microphone permission upfront (UI must be visible for the prompt)
            if #available(watchOS 10.0, *) {
                let granted = await AVAudioApplication.requestRecordPermission()
                AppLogger.general.info("Microphone permission \(granted ? "granted" : "denied")")
            } else {
                await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        AppLogger.general.info("Microphone permission \(granted ? "granted" : "denied")")
                        continuation.resume()
                    }
                }
            }
            // Auto-connect on appear
            await viewModel.connect()
            // Start location tracking
            await locationViewModel.startTracking()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            Task {
                await handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }

    private func handleScenePhaseChange(from old: ScenePhase, to new: ScenePhase) async {
        switch new {
        case .active:
            // App returned to foreground
            AppLogger.general.info("Scene phase: active")

            // Reconnect voice if we were connected before background
            if wasConnectedBeforeBackground && viewModel.state == .disconnected {
                AppLogger.general.info("Reconnecting after background")
                await viewModel.connect()
            }
            // Location stays alive in background — no need to restart
            wasConnectedBeforeBackground = false

        case .inactive:
            // Transitional state (notification shade, Control Center, raise wrist)
            // Keep connection alive during brief inactive periods
            AppLogger.general.info("Scene phase: inactive (keeping connection alive)")

            // Note: Connection stays alive during inactive state
            // This handles brief interruptions like notification pull-down
            break

        case .background:
            // App went to background or screen fully off
            AppLogger.general.info("Scene phase: background")

            wasConnectedBeforeBackground = viewModel.state.isConnected

            // Disconnect voice to conserve battery
            // Next interaction will auto-reconnect (2-3 second delay)
            if wasConnectedBeforeBackground {
                AppLogger.general.info("Disconnecting voice to conserve battery")
                await viewModel.disconnect()
            }

            // Keep location tracking active in background for caregiver monitoring
            // (requires WKBackgroundModes "location" and Always authorization)

        @unknown default:
            break
        }
    }
}

#Preview {
    ContentView()
}
