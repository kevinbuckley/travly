import SwiftUI
import SwiftData

struct AddTripSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var notes = ""

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
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Trip") {
                        createTrip()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func createTrip() {
        let manager = DataManager(modelContext: modelContext)
        manager.createTrip(
            name: name.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
    }
}
