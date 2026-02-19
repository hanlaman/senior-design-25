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
    }
}

#Preview {
    ContentView()
}
