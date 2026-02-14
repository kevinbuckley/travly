import SwiftUI
import MapKit

struct LocationSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
}

struct LocationSearchView: View {

    @Binding var selectedName: String
    @Binding var selectedLatitude: Double
    @Binding var selectedLongitude: Double

    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search for a place...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        performSearch()
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.top, 8)

            if !searchResults.isEmpty {
                // Results list
                List(searchResults) { result in
                    Button {
                        selectResult(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 180)
            }

            // Map preview
            Map(position: $cameraPosition) {
                if selectedLatitude != 0 || selectedLongitude != 0 {
                    Marker(selectedName.isEmpty ? "Selected" : selectedName,
                           coordinate: CLLocationCoordinate2D(
                               latitude: selectedLatitude,
                               longitude: selectedLongitude
                           ))
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.vertical, 8)

            if !selectedName.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(selectedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            guard let response = response else {
                searchResults = []
                return
            }
            searchResults = response.mapItems.prefix(8).map { item in
                LocationSearchResult(
                    name: item.name ?? "Unknown",
                    subtitle: item.placemark.title ?? "",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
        }
    }

    private func selectResult(_ result: LocationSearchResult) {
        selectedName = result.name
        selectedLatitude = result.latitude
        selectedLongitude = result.longitude
        searchResults = []
        searchText = result.name

        let coordinate = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
}
