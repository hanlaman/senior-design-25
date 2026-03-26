# Caregiver App

## Project Overview
iOS application for caregivers to monitor dementia patients who wear an Apple Watch. The app receives health data, location information, and alerts from the patient's watch (via cloud sync) and provides tools for caregivers to manage reminders and respond to emergencies.

## Architecture

### Data Flow
```
Apple Watch → Patient iPhone → Cloud Backend (Firebase) → Caregiver iPhone
```

The Watch connects to the patient's iPhone via Bluetooth (WatchConnectivity framework). The patient's iPhone syncs data to Firebase, which the caregiver app reads.

### Pattern: MVVM with Protocol-Based Data Abstraction
- **Models**: Plain data structs
- **ViewModels**: @Observable classes that transform data for views
- **Views**: SwiftUI views that observe ViewModels
- **Services**: Protocol-based data providers (allows swapping mock/real implementations)

### Key Protocol
`PatientDataProvider` defines all data operations. Views/ViewModels depend only on this protocol, not concrete implementations:
- `MockDataService`: Demo mode with simulated data
- Future: `FirebaseDataService` for production

## Project Structure
```
caregiverapp/
├── Models/
│   ├── Patient.swift          # Patient, EmergencyContact
│   ├── PatientFact.swift      # PatientFact, FactCategory
│   ├── Location.swift         # PatientLocation, SafeZone, Coordinate
│   ├── PatientAlert.swift     # PatientAlert, AlertType, AlertSeverity
│   └── Reminder.swift         # Reminder, ReminderType, RepeatSchedule
├── Services/
│   ├── Protocols/
│   │   └── PatientDataProvider.swift
│   ├── MockDataService.swift
│   └── PatientFactsAPIService.swift
├── ViewModels/
│   ├── DashboardViewModel.swift
│   ├── LocationViewModel.swift
│   ├── PatientFactsViewModel.swift
│   ├── AlertsViewModel.swift
│   └── RemindersViewModel.swift
├── Views/
│   ├── Components/            # Reusable UI components
│   ├── Dashboard/
│   ├── Location/
│   ├── PatientFacts/          # Patient info CRUD (feeds into watch voice context)
│   ├── Alerts/
│   └── Reminders/
├── ContentView.swift          # Tab navigation
└── caregiverappApp.swift      # App entry point
```

## Features

### 1. Dashboard
Overview of patient status, quick actions, recent alerts, and upcoming reminders.

### 2. Location & Geofencing
- Real-time patient location on map
- Safe zones with configurable radius
- Alerts when patient leaves safe zones

### 3. Patient Info (Facts)
- Caregiver-entered factual information about the patient
- Organized by category: Personal, Family, Medical, Routine, Preferences, Other
- Facts are synced to backend and injected into the watch voice assistant's context
- CRUD operations via PatientFactsAPIService → /patient-facts API endpoints

### 4. Alerts System
- Fall detection alerts
- Geofence breach alerts
- Health anomaly alerts
- Filterable by type/severity

### 6. Reminders
- Medication reminders
- Hydration reminders
- Activity reminders
- Appointment reminders
- Send to Watch option (haptic notifications)

## Demo/Simulation
MockDataService provides simulation methods for demos:
- `simulateFall()`: Triggers fall detection alert
- `simulateGeofenceExit()`: Moves patient outside safe zone
- `simulateConnectionLost()` / `restoreConnection()`: Toggle watch connectivity

## Tech Stack
- SwiftUI (iOS 18+)
- Swift 6 with strict concurrency
- MapKit for maps
- Combine for publishers

## Future Integration
When adding Firebase:
1. Create `FirebaseDataService` conforming to `PatientDataProvider`
2. Swap in `caregiverappApp.swift`:
   ```swift
   @State private var dataProvider: PatientDataProvider = FirebaseDataService()
   ```
3. No changes needed to Views or ViewModels
