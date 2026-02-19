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
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ VStack(spacing: 0)                                                  │
        // │                                                                     │
        // │ spacing: 0 removes gaps between children.                          │
        // │ This creates a seamless look where elements touch.                 │
        // └─────────────────────────────────────────────────────────────────────┘
        VStack(spacing: 0) {
            locationStatusBanner.padding()

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ Map WITH CONTENT BUILDER                                        │
            // │                                                                 │
            // │ Map(position: $mapPosition) { content }                        │
            // │                                                                 │
            // │ The binding lets the map update position AND lets you          │
            // │ programmatically change what's shown.                          │
            // │                                                                 │
            // │ Inside the closure, you add map content:                       │
            // │   - Annotations (markers/pins)                                 │
            // │   - MapCircle, MapPolyline, MapPolygon                        │
            // │   - UserAnnotation (for user location)                        │
            // └─────────────────────────────────────────────────────────────────┘
            Map(position: $mapPosition) {

                // ┌─────────────────────────────────────────────────────────────┐
                // │ CONDITIONAL MAP CONTENT                                     │
                // │                                                             │
                // │ if let location = ... { } unwraps the optional.            │
                // │ Only adds the annotation if we have a location.            │
                // └─────────────────────────────────────────────────────────────┘
                if let location = viewModel.currentLocation {
                    // ┌─────────────────────────────────────────────────────────┐
                    // │ Annotation - CUSTOM MAP MARKER                          │
                    // │                                                         │
                    // │ Annotation creates a custom view at a coordinate.      │
                    // │ Unlike Marker (simple pin), you can use any SwiftUI    │
                    // │ view as the content.                                    │
                    // │                                                         │
                    // │ Parameters:                                              │
                    // │   - Label: accessibility label                          │
                    // │   - coordinate: where to place it                       │
                    // │   - content closure: the custom view                    │
                    // └─────────────────────────────────────────────────────────┘
                    Annotation("Patient", coordinate: location.clLocation) { PatientMarker(isInSafeZone: location.isInSafeZone) }
                }

                // ┌─────────────────────────────────────────────────────────────┐
                // │ ForEach FOR MULTIPLE MAP ELEMENTS                           │
                // │                                                             │
                // │ Creates a MapCircle for each safe zone.                    │
                // │ Only enabled zones are shown (zone.isEnabled check).       │
                // └─────────────────────────────────────────────────────────────┘
                ForEach(viewModel.safeZones) { zone in
                    if zone.isEnabled {
                        // ┌─────────────────────────────────────────────────────┐
                        // │ MapCircle - CIRCULAR OVERLAY                        │
                        // │                                                     │
                        // │ Draws a circle on the map for safe zones.          │
                        // │                                                     │
                        // │ .foregroundStyle() - Fill color (with opacity)     │
                        // │ .stroke() - Border color and width                 │
                        // └─────────────────────────────────────────────────────┘
                        MapCircle(center: CLLocationCoordinate2D(latitude: zone.center.latitude, longitude: zone.center.longitude), radius: zone.radiusMeters).foregroundStyle(.blue.opacity(0.2)).stroke(.blue, lineWidth: 2)
                    }
                }
            }
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ MAP MODIFIERS                                                   │
            // │                                                                 │
            // │ .mapStyle(.standard) - Regular map (vs .satellite, .hybrid)   │
            // │ .mapControls { } - Add map control buttons                     │
            // │                                                                 │
            // │ MapUserLocationButton - Button to center on user               │
            // │ MapCompass - Compass that appears when rotated                 │
            // │ MapScaleView - Shows distance scale                            │
            // │ MapPitchToggle - Toggle 2D/3D view                             │
            // └─────────────────────────────────────────────────────────────────┘
            .mapStyle(.standard)
            .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
            bottomPanel
        }
        .navigationTitle("Location")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: { showingAddZone = true }) { Image(systemName: "plus") } } }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .sheet(isPresented:) - MODAL SHEET                                  │
        // │                                                                     │
        // │ Shows a sheet when showingAddZone becomes true.                    │
        // │ The sheet automatically dismisses when isPresented becomes false.  │
        // │                                                                     │
        // │ TRAILING CLOSURE: The view to show in the sheet.                   │
        // │ The sheet is created each time it's presented.                     │
        // └─────────────────────────────────────────────────────────────────────┘
        .sheet(isPresented: $showingAddZone) { AddSafeZoneSheet(currentLocation: viewModel.currentLocation, onAdd: { name, center, radius in viewModel.addSafeZone(name: name, center: center, radius: radius) }) }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .sheet(item:) - SHEET WITH SELECTED ITEM                            │
        // │                                                                     │
        // │ Different from isPresented - this takes an optional Identifiable.  │
        // │ When selectedZone becomes non-nil, sheet appears with that zone.   │
        // │ When sheet dismisses, selectedZone automatically becomes nil.      │
        // │                                                                     │
        // │ The closure receives the unwrapped item (zone, not zone?).         │
        // └─────────────────────────────────────────────────────────────────────┘
        .sheet(item: $selectedZone) { zone in SafeZoneDetailSheet(zone: zone, onUpdate: { viewModel.updateSafeZoneRadius($0, newRadius: $1) }, onDelete: { viewModel.removeSafeZone($0) }, onToggle: { viewModel.toggleSafeZone($0) }) }
        .onAppear { viewModel.onAppear(); if let region = viewModel.centerOnPatient() { mapPosition = .region(region) } }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: viewModel.currentLocation?.coordinate.latitude) {
            if let region = viewModel.centerOnPatient() {
                withAnimation { mapPosition = .region(region) }
            }
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
                VStack(alignment: .leading, spacing: 2) { Text(zone.name).font(.subheadline).fontWeight(.medium); Text("\(Int(zone.radiusMeters))m radius").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ SHEET VIEW WITH @Environment(\.dismiss)                                     │
// │                                                                             │
// │ Sheet views often need to dismiss themselves.                              │
// │ @Environment(\.dismiss) provides a dismiss action.                         │
// └─────────────────────────────────────────────────────────────────────────────┘
struct AddSafeZoneSheet: View {
    let currentLocation: PatientLocation?
    let onAdd: (String, CLLocationCoordinate2D, Double) -> Void

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @Environment - READING FROM SWIFTUI ENVIRONMENT                         │
    // │                                                                         │
    // │ Environment provides system values and actions.                        │
    // │ \.dismiss is an action that dismisses the current presentation.        │
    // │                                                                         │
    // │ Other useful environment values:                                        │
    // │   \.colorScheme      - Light or dark mode                              │
    // │   \.horizontalSizeClass - Compact or regular (iPhone vs iPad)          │
    // │   \.locale           - User's locale settings                          │
    // │   \.openURL          - Action to open URLs                             │
    // │   \.scenePhase       - App is active, inactive, or background          │
    // └─────────────────────────────────────────────────────────────────────────┘
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var radius: Double = 100

    var body: some View {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ NavigationStack IN SHEET                                            │
        // │                                                                     │
        // │ Sheets often have their own NavigationStack for:                   │
        // │   - Title bar                                                       │
        // │   - Toolbar buttons (Cancel, Done)                                 │
        // │   - Navigation within the sheet                                    │
        // └─────────────────────────────────────────────────────────────────────┘
        NavigationStack {
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ Form - GROUPED INPUT SECTIONS                                   │
            // │                                                                 │
            // │ Form is a container for input controls.                        │
            // │ It provides automatic styling and grouping.                    │
            // │                                                                 │
            // │ Section groups related controls with optional headers/footers. │
            // └─────────────────────────────────────────────────────────────────┘
            Form {
                Section("Zone Name") { TextField("e.g., Home, Park", text: $name) }
                Section("Location") { if let location = currentLocation { Text("Current: \(location.address ?? "Unknown")").font(.caption).foregroundStyle(.secondary) } }
                Section("Radius") { VStack(alignment: .leading) { Text("\(Int(radius)) meters").font(.headline); Slider(value: $radius, in: 25...500, step: 25) } }
            }
            .navigationTitle("Add Safe Zone").navigationBarTitleDisplayMode(.inline)
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ TOOLBAR WITH CANCEL/CONFIRM BUTTONS                             │
            // │                                                                 │
            // │ Standard pattern for sheets:                                    │
            // │   - .cancellationAction: Left side, dismisses without saving   │
            // │   - .confirmationAction: Right side, saves and dismisses       │
            // │                                                                 │
            // │ dismiss() is called to close the sheet.                        │
            // └─────────────────────────────────────────────────────────────────┘
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { if let location = currentLocation { onAdd(name, location.clLocation, radius) }; dismiss() }.disabled(name.isEmpty || currentLocation == nil) }
            }
        }
    }
}

struct SafeZoneDetailSheet: View {
    let zone: SafeZone
    let onUpdate: (SafeZone, Double) -> Void
    let onDelete: (SafeZone) -> Void
    let onToggle: (SafeZone) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var radius: Double

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ INITIALIZER WITH @State INITIALIZATION                                  │
    // │                                                                         │
    // │ We want the Slider to start at the zone's current radius.              │
    // │ _radius = State(initialValue: ...) initializes the @State.             │
    // │                                                                         │
    // │ Without this, we'd need a separate @State and use .onAppear to set it. │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(zone: SafeZone, onUpdate: @escaping (SafeZone, Double) -> Void, onDelete: @escaping (SafeZone) -> Void, onToggle: @escaping (SafeZone) -> Void) {
        self.zone = zone; self.onUpdate = onUpdate; self.onDelete = onDelete; self.onToggle = onToggle; _radius = State(initialValue: zone.radiusMeters)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { Text("Status"); Spacer(); Text(zone.isEnabled ? "Enabled" : "Disabled").foregroundStyle(.secondary) }; Button(zone.isEnabled ? "Disable Zone" : "Enable Zone") { onToggle(zone); dismiss() } }
                Section("Radius") { VStack(alignment: .leading) { Text("\(Int(radius)) meters").font(.headline); Slider(value: $radius, in: 25...500, step: 25) }; Button("Update Radius") { onUpdate(zone, radius); dismiss() } }
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
