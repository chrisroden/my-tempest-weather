import Foundation
import Observation

@Observable
final class WeatherViewModel {

    // MARK: - Published state

    var forecastResponse: ForecastResponse?
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    // MARK: - Refresh timer

    private var refreshTask: Task<Void, Never>?

    // MARK: - Configuration check

    var isConfigured: Bool {
        TempestAPIService.loadApiToken() != nil && TempestAPIService.stationId > 0
    }

    // MARK: - Convenience accessors (mirror MainWindowViewModel)

    var locationName: String { forecastResponse?.locationName ?? "–" }

    var currentTemperature: Double { forecastResponse?.currentConditions.airTemperature ?? 0 }
    var feelsLike: Double          { forecastResponse?.currentConditions.feelsLike ?? 0 }
    var weatherCondition: String   { forecastResponse?.currentConditions.conditions ?? "–" }
    var weatherIcon: String        { forecastResponse?.currentConditions.icon ?? "cloudy" }

    var todayHigh: Double {
        forecastResponse?.forecast.daily.first?.airTempHigh ?? 0
    }
    var todayLow: Double {
        forecastResponse?.forecast.daily.first?.airTempLow ?? 0
    }

    var windSpeed: Double            { forecastResponse?.currentConditions.windAvg ?? 0 }
    var windGust: Double             { forecastResponse?.currentConditions.windGust ?? 0 }
    var windDirection: Int           { forecastResponse?.currentConditions.windDirection ?? 0 }
    var windDirectionCardinal: String { forecastResponse?.currentConditions.windDirectionCardinal ?? "–" }

    var relativeHumidity: Int        { forecastResponse?.currentConditions.relativeHumidity ?? 0 }
    var seaLevelPressure: Double     { forecastResponse?.currentConditions.seaLevelPressure ?? 0 }
    var pressureTrend: String        { forecastResponse?.currentConditions.pressureTrend ?? "–" }

    var uvIndex: Double              { forecastResponse?.currentConditions.uv ?? 0 }
    var precipAccumLocalDay: Double  { forecastResponse?.currentConditions.precipAccumLocalDay ?? 0 }
    var lightningLast1hr: Int        { forecastResponse?.currentConditions.lightningStrikeCountLast1hr ?? 0 }

    var dailyForecasts: [DailyForecast] {
        Array((forecastResponse?.forecast.daily ?? []).prefix(7))
    }

    var tempUnits: String {
        UserDefaults.standard.string(forKey: "WeatherFlow.tempUnits") ?? "f"
    }
    var tempUnitSymbol: String { tempUnits == "c" ? "°C" : "°F" }

    var windUnitSymbol: String {
        let u = UserDefaults.standard.string(forKey: "WeatherFlow.windUnits") ?? "mph"
        switch u {
        case "kph": return "km/h"
        case "kts": return "kts"
        case "mps": return "m/s"
        default:    return "mph"
        }
    }

    var pressureUnitSymbol: String {
        UserDefaults.standard.string(forKey: "WeatherFlow.pressureUnits") ?? "mb"
    }

    var precipUnitSymbol: String {
        UserDefaults.standard.string(forKey: "WeatherFlow.precipUnits") ?? "in"
    }

    // MARK: - Refresh

    @MainActor
    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let service = TempestAPIService()
            forecastResponse = try await service.fetchForecast()
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Starts a repeating background refresh on the given interval (minutes).
    func startAutoRefresh(intervalMinutes: Int = 5) {
        stopAutoRefresh()
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard let self, !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit { stopAutoRefresh() }
}
