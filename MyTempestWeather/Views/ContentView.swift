import SwiftUI

struct ContentView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @Binding var showSettings: Bool
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly

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
                NavigationSplitView(columnVisibility: $columnVisibility) {
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
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }

    private enum NavItem: Hashable { case dashboard, settings }
}

#Preview {
    ContentView(showSettings: .constant(false))
        .environment(WeatherViewModel())
}
