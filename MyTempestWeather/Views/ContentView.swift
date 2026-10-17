import SwiftUI

struct ContentView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @Binding var showSettings: Bool
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly
    @State private var selectedNav: NavItem? = .dashboard
    @State private var selectedTab: NavItem = .dashboard

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem { Label("Weather", systemImage: "cloud.sun.fill") }
                        .tag(NavItem.dashboard)
                    NavigationStack {
                        LocationsView { selectedTab = .dashboard }
                    }
                    .tabItem { Label("Locations", systemImage: "list.bullet") }
                    .tag(NavItem.locations)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gear") }
                        .tag(NavItem.settings)
                }
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    List(selection: $selectedNav) {
                        Label("Dashboard", systemImage: "cloud.sun.fill").tag(NavItem.dashboard)
                        Label("Locations", systemImage: "list.bullet").tag(NavItem.locations)
                        Label("Settings",  systemImage: "gear").tag(NavItem.settings)
                    }
                    .navigationTitle("My Tempest")
                } detail: {
                    switch selectedNav {
                    case .settings:
                        SettingsView()
                    case .locations:
                        LocationsView { selectedNav = .dashboard }
                    default:
                        DashboardView()
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }

    private enum NavItem: Hashable { case dashboard, locations, settings }
}

#Preview {
    ContentView(showSettings: .constant(false))
        .environment(WeatherViewModel())
}
