import SwiftUI
import SwiftData
import MapKit
import TripCore

struct AddStopSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let day: DayEntity

    @State private var name = ""
    @State private var category: StopCategory = .attraction
    @State private var notes = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var locationName = ""

    @State private var useArrivalTime = false
    @State private var arrivalTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var useDepartureTime = false
    @State private var departureTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (latitude != 0 || longitude != 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Stop Name", text: $name)
                    CategoryPicker(selection: $category)
                } header: {
                    Text("Details")
                }

                Section {
                    LocationSearchView(
                        selectedName: $locationName,
                        selectedLatitude: $latitude,
                        selectedLongitude: $longitude
                    )
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Location")
                }

                Section {
                    Toggle("Set Arrival Time", isOn: $useArrivalTime)
                    if useArrivalTime {
                        DatePicker("Arrival", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Set Departure Time", isOn: $useDepartureTime)
                    if useDepartureTime {
                        DatePicker("Departure", selection: $departureTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Times")
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Stop") {
                        addStop()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onChange(of: locationName) { _, newValue in
                if name.isEmpty || name == locationName {
                    name = newValue
                }
            }
        }
    }

    private func addStop() {
        let manager = DataManager(modelContext: modelContext)
        let stop = manager.addStop(
            to: day,
            name: name.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            category: category,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        if useArrivalTime {
            stop.arrivalTime = arrivalTime
        }
        if useDepartureTime {
            stop.departureTime = departureTime
        }
        try? modelContext.save()
        dismiss()
    }
}
