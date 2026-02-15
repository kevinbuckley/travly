import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            mainTabView
        } else {
            WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var mainTabView: some View {
        TabView {
            NavigationStack {
                TripMapView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }

            NavigationStack {
                TripListView()
            }
            .tabItem {
                Label("Trips", systemImage: "list.bullet")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .tint(.blue)
    }
}
