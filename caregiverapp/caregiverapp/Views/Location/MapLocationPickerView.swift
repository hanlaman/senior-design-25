import SwiftUI
import MapKit

struct MapLocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedAddress: String?

    @Environment(\.dismiss) private var dismiss
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if !searchResults.isEmpty {
                searchResultsList
            }

            MapReader { proxy in
                Map(position: $mapPosition) {
                    if let coord = selectedCoordinate {
                        Marker("Safe Zone", coordinate: coord)
                            .tint(.blue)
                    }
                }
                .onTapGesture { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        selectedCoordinate = coordinate
                        searchResults = []
                        reverseGeocode(coordinate)
                    }
                }
                .mapStyle(.standard)
                .mapControls { MapCompass(); MapScaleView() }
            }
        }
        .navigationTitle("Choose Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .disabled(selectedCoordinate == nil)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search address...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit { Task { await search() } }
            if !searchText.isEmpty {
                Button(action: { searchText = ""; searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(searchResults, id: \.self) { item in
                    Button {
                        if let location = item.placemark.location?.coordinate {
                            selectedCoordinate = location
                            selectedAddress = item.placemark.title
                            searchResults = []
                            searchText = item.placemark.title ?? ""
                            mapPosition = .region(MKCoordinateRegion(
                                center: location,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            ))
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unknown").font(.subheadline).fontWeight(.medium)
                            Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading)
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color(.systemBackground))
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        let search = MKLocalSearch(request: request)
        if let response = try? await search.start() {
            searchResults = response.mapItems
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                let components = [placemark.name, placemark.locality, placemark.administrativeArea].compactMap { $0 }
                selectedAddress = components.joined(separator: ", ")
            }
        }
    }
}
