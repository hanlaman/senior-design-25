//
//  caregiverappApp.swift
//  caregiverapp
//

import SwiftUI

@main
struct caregiverappApp: App {
    @State private var dataProvider: PatientDataProvider = MockDataService()

    var body: some Scene {
        WindowGroup {
            ContentView(dataProvider: dataProvider)
        }
    }
}
