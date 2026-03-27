import SwiftUI

struct ContentView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                TabView {
                    DashboardView()
                        .tabItem { Label("Weather", systemImage: "cloud.sun.fill") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gear") }
                }
            } else {
                NavigationSplitView {
                    List {
                        NavigationLink("Dashboard", value: NavItem.dashboard)
                        NavigationLink("Settings",  value: NavItem.settings)
                    }
                    .navigationTitle("My Tempest")
                } detail: {
                    DashboardView()
                }
            }
        }
    }

    private enum NavItem: Hashable { case dashboard, settings }
}

#Preview {
    ContentView()
        .environment(WeatherViewModel())
}
