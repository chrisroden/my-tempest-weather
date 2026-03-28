import SwiftUI

@main
struct MyTempestWeatherApp: App {
    @State private var viewModel = WeatherViewModel()
    @State private var showSettings = false
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if splashDone {
                    ContentView(showSettings: $showSettings)
                        .environment(viewModel)
                        .transition(.opacity)
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: splashDone)
            .environment(viewModel)
            .task {
                if viewModel.isConfigured {
                    await viewModel.refresh()
                } else {
                    showSettings = true
                }
                withAnimation { splashDone = true }
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
