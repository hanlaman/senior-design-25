//
//  LocationView.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: MAPKIT, SHEETS, AND ENVIRONMENT VALUES
//  ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ MAPKIT FRAMEWORK                                                            │
// │                                                                             │
// │ MapKit provides map display and interaction.                               │
// │ SwiftUI's Map view (iOS 17+) is fully declarative.                        │
// │                                                                             │
// │ Key types:                                                                  │
// │   - Map: The map view itself                                               │
// │   - MapCameraPosition: Controls what's visible                             │
// │   - Annotation: Custom markers on the map                                  │
// │   - MapCircle: Circular overlays (for safe zones)                          │
// │   - MKCoordinateRegion: A geographic region                                │
// └─────────────────────────────────────────────────────────────────────────────┘
import MapKit

struct LocationView: View {
    @State private var viewModel: LocationViewModel

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ MapCameraPosition - CONTROLS MAP VIEW                                   │
    // │                                                                         │
    // │ This @State controls what the map shows.                               │
    // │ .automatic lets the map decide based on content.                       │
    // │                                                                         │
    // │ Other options:                                                          │
    // │   .region(MKCoordinateRegion) - Show specific region                   │
    // │   .camera(MapCamera) - Set camera position/pitch/heading               │
    // │   .userLocation(...) - Center on user location                         │
    // │   .item(MKMapItem) - Center on a map item                              │
    // └─────────────────────────────────────────────────────────────────────────┘
    @State private var mapPosition: MapCameraPosition = .automatic

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @State FOR SHEET PRESENTATION                                           │
    // │                                                                         │
    // │ showingAddZone controls whether the "Add Zone" sheet is visible.       │
    // │ Sheets are modal views that slide up from the bottom.                  │
    // │                                                                         │
    // │ selectedZone is OPTIONAL - when set, the detail sheet appears.         │
    // │ This pattern: Optional @State + .sheet(item:) is common for            │
    // │ showing details for a selected item.                                   │
    // └─────────────────────────────────────────────────────────────────────────┘
    @State private var showingAddZone = false
    @State private var selectedZone: SafeZone?

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: LocationViewModel(dataProvider: dataProvider))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasLoadedInitialData {
                loadingView
            } else if let errorMessage = viewModel.errorMessage, !viewModel.hasLoadedInitialData {
                errorView(message: errorMessage)
            } else {
                locationContent
            }
        }
        .navigationTitle("Location")
        .toolbar {
            if viewModel.hasLoadedInitialData {
                ToolbarItem(placement: .topBarTrailing) { Button(action: { showingAddZone = true }) { Image(systemName: "plus") } }
            }
        }
        .sheet(isPresented: $showingAddZone) { AddSafeZoneSheet(currentLocation: viewModel.currentLocation, onAdd: { name, center, radius, duration in viewModel.addSafeZone(name: name, center: center, radius: radius, durationMinutes: duration) }) }
        .sheet(item: $selectedZone) { zone in SafeZoneDetailSheet(zone: zone, onUpdate: { zone, radius, duration in viewModel.updateSafeZone(zone, newRadius: radius, newDuration: duration) }, onDelete: { viewModel.removeSafeZone($0) }, onToggle: { viewModel.toggleSafeZone($0) }) }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: viewModel.currentLocation?.coordinate.latitude) {
            if let region = viewModel.centerOnPatient() {
                withAnimation { mapPosition = .region(region) }
            }
        }
        .onChange(of: viewModel.hasLoadedInitialData) {
            if viewModel.hasLoadedInitialData, let region = viewModel.centerOnPatient() {
                mapPosition = .region(region)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading location data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connection Error")
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: { viewModel.retry() }) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var locationContent: some View {
        VStack(spacing: 0) {
            locationStatusBanner.padding()

            Map(position: $mapPosition) {
                if let location = viewModel.currentLocation {
                    Annotation("Patient", coordinate: location.clLocation) { PatientMarker(isInSafeZone: location.isInSafeZone) }
                }

                ForEach(viewModel.safeZones) { zone in
                    if zone.isEnabled {
                        MapCircle(center: CLLocationCoordinate2D(latitude: zone.center.latitude, longitude: zone.center.longitude), radius: zone.radiusMeters).foregroundStyle(.blue.opacity(0.2)).stroke(.blue, lineWidth: 2)
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
            bottomPanel
        }
    }

    private var locationStatusBanner: some View {
        HStack {
            Image(systemName: viewModel.isInSafeZone ? "checkmark.shield.fill" : "exclamationmark.triangle.fill").foregroundStyle(viewModel.isInSafeZone ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.locationStatusText).font(.subheadline).fontWeight(.medium)
                if let address = viewModel.currentLocation?.address { Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ withAnimation { } - ANIMATED STATE CHANGE                       │
            // │                                                                 │
            // │ Wrapping state changes in withAnimation { } animates the       │
            // │ resulting UI changes smoothly.                                 │
            // │                                                                 │
            // │ Here, changing mapPosition animates the map flying to          │
            // │ the new region instead of jumping instantly.                   │
            // └─────────────────────────────────────────────────────────────────┘
            Button(action: { if let region = viewModel.centerOnPatient() { withAnimation { mapPosition = .region(region) } } }) { Image(systemName: "location.fill").padding(8).background(Color.blue).foregroundStyle(.white).clipShape(Circle()) }
        }
        .padding()
        .background(viewModel.isInSafeZone ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safe Zones").font(.headline).padding(.horizontal).padding(.top)
            if viewModel.safeZones.isEmpty {
                Text("No safe zones configured").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding()
            } else {
                // ┌─────────────────────────────────────────────────────────────┐
                // │ HORIZONTAL SCROLLVIEW                                       │
                // │                                                             │
                // │ ScrollView(.horizontal, showsIndicators: false)            │
                // │   - .horizontal: Scroll left/right instead of up/down     │
                // │   - showsIndicators: false: Hide the scroll bar           │
                // └─────────────────────────────────────────────────────────────┘
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(viewModel.safeZones) { zone in SafeZoneChip(zone: zone) { selectedZone = zone } } }.padding(.horizontal) }
            }
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ CUSTOM ANNOTATION VIEW                                                      │
// │                                                                             │
// │ PatientMarker is the custom view shown on the map for the patient.         │
// │ It changes color based on safe zone status.                                │
// └─────────────────────────────────────────────────────────────────────────────┘
struct PatientMarker: View {
    let isInSafeZone: Bool
    var body: some View {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ ZStack - LAYERED VIEWS                                              │
        // │                                                                     │
        // │ ZStack places views on top of each other (back to front).          │
        // │ First view is at the bottom, last view is on top.                  │
        // │                                                                     │
        // │ Here: Colored circle → White circle → Icon                         │
        // └─────────────────────────────────────────────────────────────────────┘
        ZStack {
            Circle().fill(isInSafeZone ? .green : .orange).frame(width: 30, height: 30)
            Circle().fill(.white).frame(width: 20, height: 20)
            Image(systemName: "figure.stand").font(.caption).foregroundStyle(isInSafeZone ? .green : .orange)
        }.shadow(radius: 3)
    }
}

struct SafeZoneChip: View {
    let zone: SafeZone
    let onTap: () -> Void
    var body: some View {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ Button WITH CUSTOM CONTENT                                          │
        // │                                                                     │
        // │ Button(action:) { label } creates a tappable button.               │
        // │ The label can be any SwiftUI view.                                 │
        // │                                                                     │
        // │ .buttonStyle(.plain) removes default button styling so             │
        // │ we can completely customize the appearance.                        │
        // └─────────────────────────────────────────────────────────────────────┘
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: zone.isEnabled ? "checkmark.circle.fill" : "circle").foregroundStyle(zone.isEnabled ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) { Text(zone.name).font(.subheadline).fontWeight(.medium); Text("\(Int(zone.radiusMeters))m radius · \(zone.durationMinutes == 0 ? "Immediate" : "\(zone.durationMinutes)min")").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}

struct AddSafeZoneSheet: View {
    let currentLocation: PatientLocation?
    let onAdd: (String, CLLocationCoordinate2D, Double, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var radius: Double = 100
    @State private var durationMinutes: Double = 15
    @State private var immediateNotification = false
    @State private var locationMode: LocationMode = .currentLocation
    @State private var pickedCoordinate: CLLocationCoordinate2D?
    @State private var pickedAddress: String?

    enum LocationMode: String, CaseIterable {
        case currentLocation = "Current Location"
        case pickOnMap = "Pick on Map"
    }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        switch locationMode {
        case .currentLocation: currentLocation?.clLocation
        case .pickOnMap: pickedCoordinate
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Name") {
                    TextField("e.g., Home, Park", text: $name)
                }

                Section("Location") {
                    Picker("Source", selection: $locationMode) {
                        ForEach(LocationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch locationMode {
                    case .currentLocation:
                        if let location = currentLocation {
                            Text(location.address ?? "Current patient location")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Patient location unavailable")
                                .font(.caption).foregroundStyle(.red)
                        }
                    case .pickOnMap:
                        if let addr = pickedAddress {
                            Text(addr).font(.caption).foregroundStyle(.secondary)
                        }
                        NavigationLink("Choose on Map") {
                            MapLocationPickerView(
                                selectedCoordinate: $pickedCoordinate,
                                selectedAddress: $pickedAddress
                            )
                        }
                    }
                }

                Section("Radius") {
                    VStack(alignment: .leading) {
                        Text("\(Int(radius)) meters").font(.headline)
                        Slider(value: $radius, in: 25...500, step: 25)
                    }
                }

                Section("Grace Period") {
                    VStack(alignment: .leading) {
                        Toggle("Notify Immediately", isOn: $immediateNotification)
                        if !immediateNotification {
                            Text("\(Int(durationMinutes)) minutes").font(.headline)
                            Text("How long before alerting when patient leaves this zone").font(.caption).foregroundStyle(.secondary)
                            Slider(value: $durationMinutes, in: 5...120, step: 5)
                        } else {
                            Text("Caregiver will be notified as soon as the patient leaves this zone").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Safe Zone").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let coord = selectedCoordinate {
                            onAdd(name, coord, radius, immediateNotification ? 0 : Int(durationMinutes))
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedCoordinate == nil)
                }
            }
        }
    }
}

struct SafeZoneDetailSheet: View {
    let zone: SafeZone
    let onUpdate: (SafeZone, Double, Int) -> Void
    let onDelete: (SafeZone) -> Void
    let onToggle: (SafeZone) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var radius: Double
    @State private var durationMinutes: Double
    @State private var immediateNotification: Bool

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ INITIALIZER WITH @State INITIALIZATION                                  │
    // │                                                                         │
    // │ We want the Slider to start at the zone's current radius.              │
    // │ _radius = State(initialValue: ...) initializes the @State.             │
    // │                                                                         │
    // │ Without this, we'd need a separate @State and use .onAppear to set it. │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(zone: SafeZone, onUpdate: @escaping (SafeZone, Double, Int) -> Void, onDelete: @escaping (SafeZone) -> Void, onToggle: @escaping (SafeZone) -> Void) {
        self.zone = zone; self.onUpdate = onUpdate; self.onDelete = onDelete; self.onToggle = onToggle; _radius = State(initialValue: zone.radiusMeters); _durationMinutes = State(initialValue: Double(max(zone.durationMinutes, 5))); _immediateNotification = State(initialValue: zone.durationMinutes == 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { Text("Status"); Spacer(); Text(zone.isEnabled ? "Enabled" : "Disabled").foregroundStyle(.secondary) }; Button(zone.isEnabled ? "Disable Zone" : "Enable Zone") { onToggle(zone); dismiss() } }
                Section("Radius") { VStack(alignment: .leading) { Text("\(Int(radius)) meters").font(.headline); Slider(value: $radius, in: 25...500, step: 25) } }
                Section("Grace Period") { VStack(alignment: .leading) { Toggle("Notify Immediately", isOn: $immediateNotification); if !immediateNotification { Text("\(Int(durationMinutes)) minutes").font(.headline); Text("How long before alerting when patient leaves").font(.caption).foregroundStyle(.secondary); Slider(value: $durationMinutes, in: 5...120, step: 5) } else { Text("Caregiver will be notified as soon as the patient leaves this zone").font(.caption).foregroundStyle(.secondary) } } }
                Section { Button("Save Changes") { onUpdate(zone, radius, immediateNotification ? 0 : Int(durationMinutes)); dismiss() } }
                // ┌─────────────────────────────────────────────────────────────┐
                // │ DESTRUCTIVE BUTTON                                          │
                // │                                                             │
                // │ Button(..., role: .destructive) styles the button red      │
                // │ to indicate a dangerous/irreversible action.               │
                // └─────────────────────────────────────────────────────────────┘
                Section { Button("Delete Zone", role: .destructive) { onDelete(zone); dismiss() } }
            }
            .navigationTitle(zone.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
