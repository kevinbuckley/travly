import SwiftUI
import SwiftData
import TripCore

struct TripListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripEntity.startDate, order: .reverse) private var allTrips: [TripEntity]

    @State private var showingAddTrip = false
    @State private var tripToDelete: TripEntity?

    private var activeTrips: [TripEntity] {
        allTrips.filter { $0.status == .active }
    }

    private var upcomingTrips: [TripEntity] {
        allTrips.filter { $0.status == .planning && $0.isFuture }
    }

    private var pastTrips: [TripEntity] {
        allTrips.filter { $0.status == .completed }
    }

    private var planningCurrentTrips: [TripEntity] {
        allTrips.filter { $0.status == .planning && !$0.isFuture }
    }

    var body: some View {
        Group {
            if allTrips.isEmpty {
                emptyStateView
            } else {
                tripListContent
            }
        }
        .navigationTitle("My Trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTrip) {
            AddTripSheet()
        }
        .alert("Delete Trip?", isPresented: Binding(
            get: { tripToDelete != nil },
            set: { if !$0 { tripToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete {
                    DataManager(modelContext: modelContext).deleteTrip(trip)
                    tripToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { tripToDelete = nil }
        } message: {
            if let trip = tripToDelete {
                Text("Delete \"\(trip.name)\" and all its stops, bookings, and comments? This cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.6))
            Text("No Trips Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Plan your first adventure and keep\nyour itinerary organized.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddTrip = true
            } label: {
                Label("Plan Your First Trip", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    // MARK: - Trip List

    private var tripListContent: some View {
        List {
            if !activeTrips.isEmpty {
                Section {
                    ForEach(activeTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            TripRowView(trip: trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = activeTrips[index]
                        }
                    }
                } header: {
                    Label("Active", systemImage: "location.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !upcomingTrips.isEmpty || !planningCurrentTrips.isEmpty {
                let combined = planningCurrentTrips + upcomingTrips
                Section {
                    ForEach(combined) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            TripRowView(trip: trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = combined[index]
                        }
                    }
                } header: {
                    Label("Upcoming", systemImage: "calendar")
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !pastTrips.isEmpty {
                Section {
                    ForEach(pastTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            TripRowView(trip: trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = pastTrips[index]
                        }
                    }
                } header: {
                    Label("Past", systemImage: "checkmark.circle")
                        .foregroundStyle(.gray)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

}
