import SwiftUI
import SwiftData

struct TripListsSection: View {
    @Environment(\.modelContext) private var modelContext
    let trip: TripEntity

    @State private var showingAddList = false
    @State private var newListName = ""
    @State private var newItemTexts: [UUID: String] = [:]

    private var sortedLists: [TripListEntity] {
        trip.lists.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ForEach(sortedLists) { list in
            listSection(list)
        }

        Section {
            if showingAddList {
                HStack {
                    TextField("List name", text: $newListName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        createList()
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        showingAddList = false
                        newListName = ""
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    showingAddList = true
                } label: {
                    Label("New List", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Lists")
        }
    }

    private func listSection(_ list: TripListEntity) -> some View {
        let sortedItems = list.items.sorted { $0.sortOrder < $1.sortOrder }
        let itemText = Binding<String>(
            get: { newItemTexts[list.id] ?? "" },
            set: { newItemTexts[list.id] = $0 }
        )

        return Section {
            ForEach(sortedItems) { item in
                HStack(spacing: 10) {
                    Button {
                        item.isChecked.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isChecked ? .green : .gray)
                    }
                    .buttonStyle(.plain)

                    Text(item.text)
                        .font(.subheadline)
                        .strikethrough(item.isChecked)
                        .foregroundColor(item.isChecked ? .secondary : .primary)
                }
            }
            .onDelete { offsets in
                deleteItems(from: list, at: offsets)
            }

            HStack(spacing: 8) {
                TextField("Add item...", text: itemText)
                    .font(.subheadline)
                Button {
                    addItem(to: list, text: itemText.wrappedValue)
                    newItemTexts[list.id] = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(itemText.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .disabled(itemText.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Label(list.name, systemImage: list.icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                let checkedCount = list.items.filter(\.isChecked).count
                if !list.items.isEmpty {
                    Text("\(checkedCount)/\(list.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    modelContext.delete(list)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func createList() {
        let list = TripListEntity(name: newListName.trimmingCharacters(in: .whitespaces), sortOrder: trip.lists.count)
        list.trip = trip
        trip.lists.append(list)
        modelContext.insert(list)
        try? modelContext.save()
        newListName = ""
        showingAddList = false
    }

    private func addItem(to list: TripListEntity, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TripListItemEntity(text: trimmed, sortOrder: list.items.count)
        item.list = list
        list.items.append(item)
        modelContext.insert(item)
        try? modelContext.save()
    }

    private func deleteItems(from list: TripListEntity, at offsets: IndexSet) {
        let sorted = list.items.sorted { $0.sortOrder < $1.sortOrder }
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        try? modelContext.save()
    }
}
