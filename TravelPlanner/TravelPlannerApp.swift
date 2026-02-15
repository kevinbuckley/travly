import SwiftUI
import SwiftData

@main
struct TravelPlannerApp: App {

    let modelContainer: ModelContainer
    @State private var locationManager = LocationManager()

    init() {
        do {
            let schema = Schema([TripEntity.self, DayEntity.self, StopEntity.self, CommentEntity.self, BookingEntity.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
        }
        .modelContainer(modelContainer)
    }
}
