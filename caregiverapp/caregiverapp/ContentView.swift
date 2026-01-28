//
//  ContentView.swift
//  caregiverapp
//

import SwiftUI

struct ContentView: View {
    let dataProvider: PatientDataProvider
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                LocationView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Location", systemImage: "location.fill")
            }
            .tag(1)

            NavigationStack {
                HealthTabView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Health", systemImage: "heart.fill")
            }
            .tag(2)

            NavigationStack {
                RemindersListView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Reminders", systemImage: "bell.fill")
            }
            .tag(3)

            NavigationStack {
                AlertsListView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Alerts", systemImage: "exclamationmark.triangle.fill")
            }
            .tag(4)
        }
    }
}

struct HealthTabView: View {
    let dataProvider: PatientDataProvider

    var body: some View {
        List {
            NavigationLink {
                HeartRateView(dataProvider: dataProvider)
            } label: {
                Label("Heart Rate", systemImage: "heart.fill")
                    .foregroundStyle(.red)
            }

            NavigationLink {
                ActivityView(dataProvider: dataProvider)
            } label: {
                Label("Activity", systemImage: "figure.walk")
                    .foregroundStyle(.green)
            }
        }
        .navigationTitle("Health")
    }
}

#Preview {
    ContentView(dataProvider: MockDataService())
}
