import SwiftUI

struct SettingsView: View {
    /// Passed from the sheet's `isPresented` binding so we can close the sheet
    /// without being intercepted by the inner `NavigationStack`'s dismiss action.
    var isPresented: Binding<Bool> = .constant(true)

    @Environment(WeatherViewModel.self) private var viewModel

    @State private var apiToken: String = ""
    @State private var stationIdText: String = ""
    @State private var deviceIdText: String = ""
    @State private var refreshInterval: Int = 5
    @State private var saveError: String?
    @State private var saveSuccess = false
    @State private var tempUnits: String = "f"
    @State private var windUnits: String = "mph"
    @State private var pressureUnits: String = "mb"
    @State private var precipUnits: String = "in"

    private let refreshOptions = [1, 2, 5, 10, 15, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Token", text: $apiToken)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    TextField("Station ID", text: $stationIdText)
                        .keyboardType(.numberPad)
                    TextField("Device ID", text: $deviceIdText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("WeatherFlow Credentials")
                } footer: {
                    Text("Find your token and station ID at tempestwx.com → Settings → Data Authorizations. Device ID enables real-time WebSocket updates.")
                        .font(.caption)
                }

                Section("Refresh Interval") {
                    Picker("Auto-refresh every", selection: $refreshInterval) {
                        ForEach(refreshOptions, id: \.self) { mins in
                            Text(mins == 1 ? "1 minute" : "\(mins) minutes").tag(mins)
                        }
                    }
                }

                Section("Display Units") {
                    Picker("Temperature", selection: $tempUnits) {
                        Text("°F").tag("f")
                        Text("°C").tag("c")
                    }
                    Picker("Wind Speed", selection: $windUnits) {
                        Text("mph").tag("mph")
                        Text("km/h").tag("kph")
                        Text("Knots").tag("kts")
                        Text("m/s").tag("mps")
                    }
                    Picker("Pressure", selection: $pressureUnits) {
                        Text("mb").tag("mb")
                        Text("hPa").tag("hpa")
                        Text("inHg").tag("inhg")
                        Text("mmHg").tag("mmhg")
                    }
                    Picker("Precipitation", selection: $precipUnits) {
                        Text("in").tag("in")
                        Text("mm").tag("mm")
                    }
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if saveSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Settings saved")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented.wrappedValue = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
    }

    // MARK: - Load / Save

    private func load() {
        apiToken = TempestAPIService.loadApiToken() ?? ""
        let id = TempestAPIService.stationId
        stationIdText = id > 0 ? "\(id)" : ""
        let devId = TempestAPIService.deviceId
        deviceIdText = devId > 0 ? "\(devId)" : ""
        refreshInterval = UserDefaults.standard.integer(forKey: "WeatherFlow.refreshIntervalMinutes") == 0
            ? 5
            : UserDefaults.standard.integer(forKey: "WeatherFlow.refreshIntervalMinutes")
        tempUnits     = UserDefaults.standard.string(forKey: "WeatherFlow.tempUnits")     ?? "f"
        windUnits     = UserDefaults.standard.string(forKey: "WeatherFlow.windUnits")     ?? "mph"
        pressureUnits = UserDefaults.standard.string(forKey: "WeatherFlow.pressureUnits") ?? "mb"
        precipUnits   = UserDefaults.standard.string(forKey: "WeatherFlow.precipUnits")   ?? "in"
    }

    private func save() {
        saveError = nil
        saveSuccess = false

        guard !apiToken.trimmingCharacters(in: .whitespaces).isEmpty else {
            saveError = "API token is required."
            return
        }
        guard let id = Int(stationIdText.trimmingCharacters(in: .whitespaces)), id > 0 else {
            saveError = "A valid station ID is required."
            return
        }

        TempestAPIService.saveApiToken(apiToken.trimmingCharacters(in: .whitespaces))
        TempestAPIService.stationId = id
        if let devId = Int(deviceIdText.trimmingCharacters(in: .whitespaces)), devId > 0 {
            TempestAPIService.deviceId = devId
        }
        UserDefaults.standard.set(refreshInterval, forKey: "WeatherFlow.refreshIntervalMinutes")
        UserDefaults.standard.set(tempUnits,     forKey: "WeatherFlow.tempUnits")
        UserDefaults.standard.set(windUnits,     forKey: "WeatherFlow.windUnits")
        UserDefaults.standard.set(pressureUnits, forKey: "WeatherFlow.pressureUnits")
        UserDefaults.standard.set(precipUnits,   forKey: "WeatherFlow.precipUnits")

        saveSuccess = true

        // Kick off an immediate refresh with new credentials
        Task {
            await viewModel.refresh()
            viewModel.startAutoRefresh(intervalMinutes: refreshInterval)
            viewModel.stopWebSocket()
            viewModel.startWebSocket()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented.wrappedValue = false
        }
    }
}

#Preview {
    SettingsView()
        .environment(WeatherViewModel())
}
