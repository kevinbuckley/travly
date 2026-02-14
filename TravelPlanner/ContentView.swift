import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            NavigationStack {
                TripListView()
            }
            .tabItem {
                Label("Trips", systemImage: "list.bullet")
            }

            NavigationStack {
                TripMapView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
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
