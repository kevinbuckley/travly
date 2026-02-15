import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Screenshot mode: pass `-screenshotTab trips` (or `map`, `settings`) as launch arg
    private var screenshotTab: String? {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-screenshotTab"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            return ProcessInfo.processInfo.arguments[idx + 1]
        }
        return nil
    }

    private var isScreenshotMode: Bool { screenshotTab != nil }

    @State private var selectedTab = 0
    @State private var tripsNavPath = NavigationPath()
    @Query(sort: \TripEntity.startDate, order: .reverse) private var allTrips: [TripEntity]

    var body: some View {
        if hasCompletedOnboarding || isScreenshotMode {
            mainTabView
                .onAppear {
                    if isScreenshotMode {
                        seedScreenshotDataIfNeeded()
                        switch screenshotTab {
                        case "map": selectedTab = 0
                        case "trips": selectedTab = 1
                        case "settings": selectedTab = 2
                        case "tripdetail":
                            selectedTab = 1
                            // Push to first trip after a short delay so data is loaded
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let first = allTrips.first(where: { $0.status == .active }) ?? allTrips.first {
                                    tripsNavPath.append(first.id)
                                }
                            }
                        default: selectedTab = 1
                        }
                    }
                }
        } else {
            WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TripMapView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(0)

            NavigationStack(path: $tripsNavPath) {
                TripListView()
                    .navigationDestination(for: UUID.self) { tripID in
                        if let trip = allTrips.first(where: { $0.id == tripID }) {
                            TripDetailView(trip: trip)
                        }
                    }
            }
            .tabItem {
                Label("Trips", systemImage: "list.bullet")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .tint(.blue)
    }

    private func seedScreenshotDataIfNeeded() {
        let descriptor = FetchDescriptor<TripEntity>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count == 0 {
            let manager = DataManager(modelContext: modelContext)
            manager.loadSampleDataIfEmpty()
        }
    }
}
