//
//  LocationView.swift
//  caregiverapp
//

import SwiftUI
import MapKit

struct LocationView: View {
    @State private var viewModel: LocationViewModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showingAddZone = false
    @State private var selectedZone: SafeZone?

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: LocationViewModel(dataProvider: dataProvider))
    }

    var body: some View {
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
        .navigationTitle("Location")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: { showingAddZone = true }) { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingAddZone) { AddSafeZoneSheet(currentLocation: viewModel.currentLocation, onAdd: { name, center, radius in viewModel.addSafeZone(name: name, center: center, radius: radius) }) }
        .sheet(item: $selectedZone) { zone in SafeZoneDetailSheet(zone: zone, onUpdate: { viewModel.updateSafeZoneRadius($0, newRadius: $1) }, onDelete: { viewModel.removeSafeZone($0) }, onToggle: { viewModel.toggleSafeZone($0) }) }
        .onAppear { viewModel.onAppear(); if let region = viewModel.centerOnPatient() { mapPosition = .region(region) } }
    }

    private var locationStatusBanner: some View {
        HStack {
            Image(systemName: viewModel.isInSafeZone ? "checkmark.shield.fill" : "exclamationmark.triangle.fill").foregroundStyle(viewModel.isInSafeZone ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.locationStatusText).font(.subheadline).fontWeight(.medium)
                if let address = viewModel.currentLocation?.address { Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
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
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(viewModel.safeZones) { zone in SafeZoneChip(zone: zone) { selectedZone = zone } } }.padding(.horizontal) }
            }
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
}

struct PatientMarker: View {
    let isInSafeZone: Bool
    var body: some View {
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
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: zone.isEnabled ? "checkmark.circle.fill" : "circle").foregroundStyle(zone.isEnabled ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) { Text(zone.name).font(.subheadline).fontWeight(.medium); Text("\(Int(zone.radiusMeters))m radius").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}

struct AddSafeZoneSheet: View {
    let currentLocation: PatientLocation?
    let onAdd: (String, CLLocationCoordinate2D, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var radius: Double = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Name") { TextField("e.g., Home, Park", text: $name) }
                Section("Location") { if let location = currentLocation { Text("Current: \(location.address ?? "Unknown")").font(.caption).foregroundStyle(.secondary) } }
                Section("Radius") { VStack(alignment: .leading) { Text("\(Int(radius)) meters").font(.headline); Slider(value: $radius, in: 25...500, step: 25) } }
            }
            .navigationTitle("Add Safe Zone").navigationBarTitleDisplayMode(.inline)
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

    init(zone: SafeZone, onUpdate: @escaping (SafeZone, Double) -> Void, onDelete: @escaping (SafeZone) -> Void, onToggle: @escaping (SafeZone) -> Void) {
        self.zone = zone; self.onUpdate = onUpdate; self.onDelete = onDelete; self.onToggle = onToggle; _radius = State(initialValue: zone.radiusMeters)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { Text("Status"); Spacer(); Text(zone.isEnabled ? "Enabled" : "Disabled").foregroundStyle(.secondary) }; Button(zone.isEnabled ? "Disable Zone" : "Enable Zone") { onToggle(zone); dismiss() } }
                Section("Radius") { VStack(alignment: .leading) { Text("\(Int(radius)) meters").font(.headline); Slider(value: $radius, in: 25...500, step: 25) }; Button("Update Radius") { onUpdate(zone, radius); dismiss() } }
                Section { Button("Delete Zone", role: .destructive) { onDelete(zone); dismiss() } }
            }
            .navigationTitle(zone.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
