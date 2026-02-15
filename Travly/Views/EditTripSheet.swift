import SwiftUI
import SwiftData
import TripCore

struct EditTripSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity

    @State private var name: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String
    @State private var status: TripStatus
    @State private var showingDateChangeWarning = false

    init(trip: TripEntity) {
        self.trip = trip
        _name = State(initialValue: trip.name)
        _destination = State(initialValue: trip.destination)
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _notes = State(initialValue: trip.notes)
        _status = State(initialValue: trip.status)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                } header: {
                    Text("Details")
                }

                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                } header: {
                    Text("Dates")
                }

                Section {
                    Picker("Status", selection: $status) {
                        Text("Planning").tag(TripStatus.planning)
                        Text("Active").tag(TripStatus.active)
                        Text("Completed").tag(TripStatus.completed)
                    }
                } header: {
                    Text("Status")
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        attemptSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .alert("Change Trip Dates?", isPresented: $showingDateChangeWarning) {
                Button("Change Dates", role: .destructive) {
                    saveChanges(regenerateDays: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Changing dates will regenerate the day-by-day plan. All existing stops and comments will be removed.")
            }
        }
    }

    private func attemptSave() {
        let datesChanged = trip.startDate != startDate || trip.endDate != endDate
        let hasStops = trip.days.contains { !$0.stops.isEmpty }

        if datesChanged && hasStops {
            showingDateChangeWarning = true
        } else {
            saveChanges(regenerateDays: datesChanged)
        }
    }

    private func saveChanges(regenerateDays: Bool) {
        let manager = DataManager(modelContext: modelContext)
        trip.name = name.trimmingCharacters(in: .whitespaces)
        trip.destination = destination.trimmingCharacters(in: .whitespaces)
        trip.startDate = startDate
        trip.endDate = endDate
        trip.notes = notes.trimmingCharacters(in: .whitespaces)
        trip.status = status

        if regenerateDays {
            manager.generateDays(for: trip)
        }

        manager.updateTrip(trip)
        dismiss()
    }
}
