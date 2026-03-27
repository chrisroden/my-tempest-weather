import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WeatherViewModel.self) private var viewModel

    @State private var apiToken: String = ""
    @State private var stationIdText: String = ""
    @State private var refreshInterval: Int = 5
    @State private var saveError: String?
    @State private var saveSuccess = false

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
                } header: {
                    Text("WeatherFlow Credentials")
                } footer: {
                    Text("Find your token and station ID at tempestwx.com → Settings → Data Authorizations.")
                        .font(.caption)
                }

                Section("Refresh Interval") {
                    Picker("Auto-refresh every", selection: $refreshInterval) {
                        ForEach(refreshOptions, id: \.self) { mins in
                            Text(mins == 1 ? "1 minute" : "\(mins) minutes").tag(mins)
                        }
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
                    Button("Cancel") { dismiss() }
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
        refreshInterval = UserDefaults.standard.integer(forKey: "WeatherFlow.refreshIntervalMinutes") == 0
            ? 5
            : UserDefaults.standard.integer(forKey: "WeatherFlow.refreshIntervalMinutes")
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
        UserDefaults.standard.set(refreshInterval, forKey: "WeatherFlow.refreshIntervalMinutes")

        saveSuccess = true

        // Kick off an immediate refresh with new credentials
        Task {
            await viewModel.refresh()
            viewModel.startAutoRefresh(intervalMinutes: refreshInterval)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environment(WeatherViewModel())
}
