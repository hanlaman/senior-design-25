//
//  ContentView.swift
//  reMIND Watch App
//
//  Main view for voice assistant with vertical page navigation
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel = VoiceViewModel()
    @StateObject private var locationViewModel = LocationViewModel()
    @State private var currentPage: NavigationPage? = .voice
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasConnectedBeforeBackground = false

    enum NavigationPage: Int, CaseIterable, Hashable {
        case voice = 0
        case settings = 1
    }

    var body: some View {
        TabView(selection: $currentPage) {
            // Main voice page (full screen, tappable)
            VoicePageView(viewModel: viewModel)
                .tag(NavigationPage.voice as NavigationPage?)

            // Settings page (swipe down to reveal)
            // Wrapped in NavigationStack to enable drill-down navigation
            NavigationStack {
                SettingsPageView(state: viewModel.state, locationViewModel: locationViewModel)
            }
            .tag(NavigationPage.settings as NavigationPage?)
        }
        .tabViewStyle(.verticalPage)
        // Disable page swiping during recording to prevent accidental navigation
        .allowsHitTesting(!viewModel.state.isRecording)
        .ignoresSafeArea()
        .task {
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
            // App returned to foreground - reconnect if we were connected before
            if wasConnectedBeforeBackground && viewModel.state == .disconnected {
                await viewModel.connect()
                await locationViewModel.startTracking()
            }
            wasConnectedBeforeBackground = false

        case .inactive:
            // Transitional state (notification shade, Control Center)
            // Keep connection alive - don't disconnect for brief interruptions
            break

        case .background:
            // App went to background or sleep - disconnect to conserve resources
            wasConnectedBeforeBackground = viewModel.state.isConnected
            await viewModel.disconnect()
            await locationViewModel.stopTracking()

        @unknown default:
            break
        }
    }
}

#Preview {
    ContentView()
}
