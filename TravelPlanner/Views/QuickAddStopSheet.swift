import SwiftUI
import SwiftData
import CoreLocation
import TripCore

struct QuickAddStopSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager

    let day: DayEntity

    @State private var resolvedName: String?
    @State private var isGeocoding = false
    @State private var didAdd = false

    private var hasLocation: Bool {
        locationManager.currentLocation != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                locationStatusSection
                Spacer()
            }
            .padding(16)
            .navigationTitle("I'm Here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                requestLocationIfNeeded()
            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                if let loc = newLocation {
                    reverseGeocodeAndAdd(loc)
                }
            }
        }
    }

    // MARK: - Location Status

    private var locationStatusSection: some View {
        VStack(spacing: 12) {
            if didAdd, let name = resolvedName {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text(name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Added to today's itinerary")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.large)
                Text(isGeocoding ? "Finding place name..." : "Getting your location...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func requestLocationIfNeeded() {
        if !locationManager.isAuthorized {
            locationManager.requestPermission()
        } else {
            locationManager.requestLocation()
        }
    }

    private func reverseGeocodeAndAdd(_ location: CLLocation) {
        guard !didAdd else { return }
        isGeocoding = true
        let geocoder = CLGeocoder()
        Task {
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            await MainActor.run {
                isGeocoding = false
                let placemark = placemarks?.first
                // Use the place name (e.g. "Starbucks", "Central Park") or fall back to address
                let placeName = placemark?.name
                    ?? placemark?.locality
                    ?? "Current Location"

                resolvedName = placeName
                addStop(name: placeName, location: location)
            }
        }
    }

    private func addStop(name: String, location: CLLocation) {
        let manager = DataManager(modelContext: modelContext)
        let stop = manager.addStop(
            to: day,
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            category: .other
        )
        stop.arrivalTime = Date()
        try? modelContext.save()
        didAdd = true

        // Auto-dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}
