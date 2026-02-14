import SwiftUI
import SwiftData
import TripCore

struct EditStopSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let stop: StopEntity

    @State private var name: String
    @State private var category: StopCategory
    @State private var notes: String
    @State private var useArrivalTime: Bool
    @State private var arrivalTime: Date
    @State private var useDepartureTime: Bool
    @State private var departureTime: Date

    init(stop: StopEntity) {
        self.stop = stop
        _name = State(initialValue: stop.name)
        _category = State(initialValue: stop.category)
        _notes = State(initialValue: stop.notes)
        _useArrivalTime = State(initialValue: stop.arrivalTime != nil)
        _arrivalTime = State(initialValue: stop.arrivalTime ?? Date())
        _useDepartureTime = State(initialValue: stop.departureTime != nil)
        _departureTime = State(initialValue: stop.departureTime ?? Date())
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
            .navigationTitle("Edit Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveChanges() {
        stop.name = name.trimmingCharacters(in: .whitespaces)
        stop.category = category
        stop.notes = notes.trimmingCharacters(in: .whitespaces)
        stop.arrivalTime = useArrivalTime ? arrivalTime : nil
        stop.departureTime = useDepartureTime ? departureTime : nil
        try? modelContext.save()
        dismiss()
    }
}
