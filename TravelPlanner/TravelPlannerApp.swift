import SwiftUI
import SwiftData

@main
struct TravelPlannerApp: App {

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([TripEntity.self, DayEntity.self, StopEntity.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    let context = modelContainer.mainContext
                    let manager = DataManager(modelContext: context)
                    manager.loadSampleDataIfEmpty()
                }
        }
        .modelContainer(modelContainer)
    }
}
