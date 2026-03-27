import SwiftUI

@main
struct MyTempestWeatherApp: App {
    @State private var viewModel = WeatherViewModel()
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView(showSettings: $showSettings)
                .environment(viewModel)
                .onAppear {
                    if viewModel.isConfigured {
                        Task { await viewModel.refresh() }
                    } else {
                        showSettings = true
                    }
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings…") { showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}
