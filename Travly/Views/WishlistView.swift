import SwiftUI
import SwiftData
import MapKit
import TripCore

struct WishlistView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistItemEntity.createdAt, order: .reverse) private var items: [WishlistItemEntity]
    @Query(sort: \TripEntity.startDate, order: .reverse) private var allTrips: [TripEntity]

    @State private var showingAddItem = false
    @State private var itemToAddToTrip: WishlistItemEntity?

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Wishlist")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddItem = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddWishlistItemSheet()
        }
        .sheet(item: $itemToAddToTrip) { item in
            AddWishlistToTripSheet(item: item, trips: allTrips)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundStyle(.pink.opacity(0.6))
            Text("No Saved Places")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Save places you want to visit.\nAdd them to trips later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingAddItem = true } label: {
                Label("Save a Place", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            Spacer()
        }
        .padding()
    }

    private var listContent: some View {
        List {
            ForEach(items) { item in
                wishlistRow(item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(item)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            itemToAddToTrip = item
                        } label: {
                            Label("Add to Trip", systemImage: "plus.circle")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func wishlistRow(_ item: WishlistItemEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon(item.category))
                .font(.body)
                .foregroundStyle(categoryColor(item.category))
                .frame(width: 32, height: 32)
                .background(categoryColor(item.category).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !item.destination.isEmpty {
                    Text(item.destination)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                itemToAddToTrip = item
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func categoryIcon(_ cat: StopCategory) -> String {
        switch cat {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private func categoryColor(_ cat: StopCategory) -> Color {
        switch cat {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}

// MARK: - Add Wishlist Item Sheet

struct AddWishlistItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var category: StopCategory = .attraction
    @State private var notes = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var locationName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Place Name", text: $name)
                    TextField("City / Region", text: $destination)
                    CategoryPicker(selection: $category)
                } header: { Text("Details") }

                Section {
                    LocationSearchView(
                        selectedName: $locationName,
                        selectedLatitude: $latitude,
                        selectedLongitude: $longitude
                    )
                    .listRowInsets(EdgeInsets())
                } header: { Text("Location (optional)") }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: { Text("Notes") }
            }
            .navigationTitle("Save a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: locationName) { _, newValue in
                if name.isEmpty { name = newValue }
            }
        }
    }

    private func saveItem() {
        let item = WishlistItemEntity(
            name: name.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            category: category,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Wishlist Item to Trip Sheet

struct AddWishlistToTripSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: WishlistItemEntity
    let trips: [TripEntity]

    @State private var selectedTrip: TripEntity?
    @State private var selectedDay: DayEntity?
    @State private var added = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(trips.filter { $0.status != .completed }) { trip in
                        Button {
                            selectedTrip = trip
                            selectedDay = trip.days.sorted(by: { $0.dayNumber < $1.dayNumber }).first
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(trip.name).font(.subheadline).fontWeight(.medium)
                                    Text(trip.destination).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedTrip?.id == trip.id {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                } header: { Text("Select Trip") }

                if let trip = selectedTrip {
                    let sortedDays = trip.days.sorted { $0.dayNumber < $1.dayNumber }
                    if !sortedDays.isEmpty {
                        Section {
                            ForEach(sortedDays) { day in
                                Button {
                                    selectedDay = day
                                } label: {
                                    HStack {
                                        Text("Day \(day.dayNumber)").font(.subheadline)
                                        Text(day.formattedDate).font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        if selectedDay?.id == day.id {
                                            Image(systemName: "checkmark").foregroundStyle(.blue)
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        } header: { Text("Select Day") }
                    }
                }

                if added {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Added \(item.name) to the trip!")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Add to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addToTrip() }
                        .disabled(selectedDay == nil)
                }
            }
        }
    }

    private func addToTrip() {
        guard let day = selectedDay else { return }
        let manager = DataManager(modelContext: modelContext)
        let stop = manager.addStop(
            to: day,
            name: item.name,
            latitude: item.latitude,
            longitude: item.longitude,
            category: item.category,
            notes: item.notes
        )
        stop.address = item.address
        stop.phone = item.phone
        stop.website = item.website
        try? modelContext.save()
        added = true
    }
}
