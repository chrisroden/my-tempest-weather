import Foundation
import Observation

@Observable
@MainActor
final class WeatherViewModel {

    // MARK: - REST state

    var forecastResponse: ForecastResponse?
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    // MARK: - Live WebSocket overrides

    var isWebSocketConnected = false
    private var liveWindSpeedMps: Double?
    private var liveWindGustMps: Double?
    private var liveWindDirectionDeg: Int?
    private var liveAirTempC: Double?
    private var liveHumidity: Int?
    private var livePressureMb: Double?
    private var liveUV: Double?
    private var livePrecipDayMm: Double?

    // MARK: - Services (not observed)

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var webSocketService: TempestWebSocketService?

    // MARK: - Configuration

    var isConfigured: Bool {
        TempestAPIService.loadApiToken() != nil && TempestAPIService.stationId > 0
    }

    // MARK: - Display properties

    var locationName: String { forecastResponse?.locationName ?? "–" }

    var currentTemperature: Double {
        if let c = liveAirTempC { return convertTempC(c) }
        return forecastResponse?.currentConditions.airTemperature ?? 0
    }
    var feelsLike: Double        { forecastResponse?.currentConditions.feelsLike ?? 0 }
    var weatherCondition: String { forecastResponse?.currentConditions.conditions ?? "–" }
    var weatherIcon: String      { forecastResponse?.currentConditions.icon ?? "cloudy" }

    var todayHigh: Double { forecastResponse?.forecast.daily.first?.airTempHigh ?? 0 }
    var todayLow: Double  { forecastResponse?.forecast.daily.first?.airTempLow  ?? 0 }

    var windSpeed: Double {
        if let mps = liveWindSpeedMps { return convertWindMps(mps) }
        return forecastResponse?.currentConditions.windAvg ?? 0
    }
    var windGust: Double {
        if let mps = liveWindGustMps { return convertWindMps(mps) }
        return forecastResponse?.currentConditions.windGust ?? 0
    }
    var windDirection: Int {
        liveWindDirectionDeg ?? forecastResponse?.currentConditions.windDirection ?? 0
    }
    var windDirectionCardinal: String {
        if let deg = liveWindDirectionDeg { return Self.cardinal(from: deg) }
        return forecastResponse?.currentConditions.windDirectionCardinal ?? "–"
    }

    var relativeHumidity: Int {
        liveHumidity ?? forecastResponse?.currentConditions.relativeHumidity ?? 0
    }
    var seaLevelPressure: Double {
        livePressureMb ?? forecastResponse?.currentConditions.seaLevelPressure ?? 0
    }
    var pressureTrend: String { forecastResponse?.currentConditions.pressureTrend ?? "–" }

    var uvIndex: Double {
        liveUV ?? forecastResponse?.currentConditions.uv ?? 0
    }
    var precipAccumLocalDay: Double {
        if let mm = livePrecipDayMm { return convertPrecipMm(mm) }
        return forecastResponse?.currentConditions.precipAccumLocalDay ?? 0
    }
    var lightningLast1hr: Int { forecastResponse?.currentConditions.lightningStrikeCountLast1hr ?? 0 }

    var dailyForecasts: [DailyForecast] {
        Array((forecastResponse?.forecast.daily ?? []).prefix(7))
    }

    // MARK: - Unit symbols

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

    // MARK: - REST refresh

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            forecastResponse = try await TempestAPIService().fetchForecast()
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

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

    // MARK: - WebSocket

    func startWebSocket() {
        guard let token = TempestAPIService.loadApiToken(),
              TempestAPIService.deviceId > 0 else { return }
        stopWebSocket()
        let service = TempestWebSocketService()
        service.onConnectionChange = { [weak self] connected in
            self?.isWebSocketConnected = connected
        }
        service.onRapidWind = { [weak self] speedMps, dir in
            self?.liveWindSpeedMps = speedMps
            self?.liveWindDirectionDeg = dir
        }
        service.onObsSt = { [weak self] obs in
            guard let self else { return }
            self.liveWindGustMps  = obs[safe: 3]
            self.liveAirTempC     = obs[safe: 7]
            if let h = obs[safe: 8] { self.liveHumidity = Int(h) }
            self.livePressureMb   = obs[safe: 6]
            self.liveUV           = obs[safe: 10]
            self.livePrecipDayMm  = obs[safe: 18]
        }
        webSocketService = service
        service.connect(token: token, deviceId: TempestAPIService.deviceId)
    }

    func stopWebSocket() {
        webSocketService?.disconnect()
        webSocketService = nil
        isWebSocketConnected = false
    }

    // MARK: - Unit conversion

    private func convertWindMps(_ mps: Double) -> Double {
        let u = UserDefaults.standard.string(forKey: "WeatherFlow.windUnits") ?? "mph"
        switch u {
        case "kph": return mps * 3.6
        case "kts": return mps * 1.94384
        case "mps": return mps
        default:    return mps * 2.23694
        }
    }

    private func convertTempC(_ c: Double) -> Double {
        tempUnits == "c" ? c : (c * 9 / 5) + 32
    }

    private func convertPrecipMm(_ mm: Double) -> Double {
        let u = UserDefaults.standard.string(forKey: "WeatherFlow.precipUnits") ?? "in"
        return u == "in" ? mm * 0.0393701 : mm
    }

    private static func cardinal(from degrees: Int) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                    "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return dirs[Int((Double(degrees) / 22.5).rounded()) % 16]
    }

    deinit { refreshTask?.cancel() }
}

// MARK: - Array helper

private extension Array where Element == Double? {
    subscript(safe index: Int) -> Double? {
        guard index < count else { return nil }
        return self[index]
    }
}
