import SwiftUI
import SwiftData
import MapKit
import TripCore

struct TripMapView: View {

    @Query(sort: \TripEntity.startDate, order: .reverse) private var allTrips: [TripEntity]

    @State private var selectedTripID: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var selectedTrip: TripEntity? {
        if let id = selectedTripID {
            return allTrips.first { $0.id == id }
        }
        return allTrips.first
    }

    private var allStops: [StopEntity] {
        guard let trip = selectedTrip else { return [] }
        return trip.days.flatMap { $0.stops }
    }

    var body: some View {
        VStack(spacing: 0) {
            if allTrips.isEmpty {
                emptyMapState
            } else {
                // Trip picker
                if allTrips.count > 1 {
                    tripPicker
                }

                // Map
                mapContent
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedTripID == nil {
                selectedTripID = allTrips.first?.id
            }
        }
        .onChange(of: selectedTripID) { _, _ in
            fitAllStops()
        }
    }

    // MARK: - Empty State

    private var emptyMapState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundStyle(.blue.opacity(0.5))
            Text("No Trips to Display")
                .font(.title3)
                .fontWeight(.medium)
            Text("Create a trip with stops to see them on the map.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Trip Picker

    private var tripPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTrips) { trip in
                    let isSelected = trip.id == (selectedTripID ?? allTrips.first?.id)
                    Button {
                        selectedTripID = trip.id
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(trip.status))
                                .frame(width: 8, height: 8)
                            Text(trip.name)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue.opacity(0.12) : Color(.systemGray6))
                        .foregroundStyle(isSelected ? .blue : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Map

    private var mapContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(allStops) { stop in
                    Marker(
                        stop.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: stop.latitude,
                            longitude: stop.longitude
                        )
                    )
                    .tint(markerColor(for: stop.category))
                }
            }
            .onAppear {
                fitAllStops()
            }

            // Fit all button
            if !allStops.isEmpty {
                Button {
                    fitAllStops()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(10)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func fitAllStops() {
        guard !allStops.isEmpty else {
            cameraPosition = .automatic
            return
        }

        let lats = allStops.map(\.latitude)
        let lons = allStops.map(\.longitude)

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.4, 0.01)
        let spanLon = max((maxLon - minLon) * 1.4, 0.01)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
        withAnimation {
            cameraPosition = .region(region)
        }
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .planning: .blue
        case .active: .green
        case .completed: .gray
        }
    }

    private func markerColor(for category: StopCategory) -> Color {
        switch category {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}
