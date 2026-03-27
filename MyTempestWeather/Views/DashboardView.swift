import SwiftUI

struct DashboardView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @State private var showSettings = false
    @State private var refreshIntervalMinutes = UserDefaults.standard.integer(forKey: "WeatherFlow.refreshIntervalMinutes") == 0 ? 5 : UserDefaults.standard.integer(forKey: "WeatherFlow.refreshIntervalMinutes")

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Current conditions + wind side by side on wide layouts
                LazyVGrid(columns: columns, spacing: 16) {
                    CurrentConditionsView()
                    WindView()
                }
                .padding(.horizontal)

                MetricsView()
                    .padding(.horizontal)

                ForecastView()
                    .padding(.horizontal)

                if let updated = viewModel.lastUpdated {
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle(viewModel.locationName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Settings") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            if viewModel.isConfigured {
                if viewModel.forecastResponse == nil {
                    await viewModel.refresh()
                }
                viewModel.startAutoRefresh(intervalMinutes: refreshIntervalMinutes)
            }
        }
        .onDisappear { viewModel.stopAutoRefresh() }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environment(WeatherViewModel())
    }
}
