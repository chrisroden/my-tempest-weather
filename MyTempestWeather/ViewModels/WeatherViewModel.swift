import Foundation
import CoreLocation
import Observation
import WeatherKit
import os

@Observable
@MainActor
final class WeatherViewModel {

    // MARK: - Locations

    /// The location the dashboard shows. `.station` uses Tempest; anything else uses WeatherKit.
    private(set) var selection: LocationSelection = .station
    private(set) var savedLocations: [SavedLocation] = []

    /// `true` when the Tempest station is selected (live WebSocket data is only available there).
    var isStationSelected: Bool { selection == .station }

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
    @ObservationIgnored private let weatherKitService: IWeatherKitService
    @ObservationIgnored private let locationService: ILocationService
    @ObservationIgnored private let locationStore: ILocationStore

    private static let logger = Logger(subsystem: "com.chrisroden.MyTempestWeather", category: "WeatherViewModel")

    // MARK: - Init

    /// Creates the view model and restores saved locations and the last selection.
    /// - Parameters:
    ///   - weatherKitService: Source for non-station locations.
    ///   - locationService: Source for the device location and place details; a `LocationService` by default.
    ///   - locationStore: Persistence for saved locations and the selection.
    init(weatherKitService: IWeatherKitService = WeatherKitService(),
         locationService: ILocationService? = nil,
         locationStore: ILocationStore = LocationStore()) {
        self.weatherKitService = weatherKitService
        self.locationService = locationService ?? LocationService()
        self.locationStore = locationStore
        do {
            savedLocations = try locationStore.loadSavedLocations()
            let stored = try locationStore.loadSelection()
            if case .saved(let id) = stored, !savedLocations.contains(where: { $0.id == id }) {
                selection = .station
            } else {
                selection = stored
            }
        } catch {
            Self.logger.error("Could not restore locations: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Saved locations could not be loaded."
        }
    }

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

    func hourlyForecasts(for day: DailyForecast) -> [HourlyForecast] {
        (forecastResponse?.forecast.hourly ?? []).filter { $0.localDay == day.dayNum }
    }

    /// Returns `true` if the daily low temperature occurs earlier in the day than the daily high,
    /// based on hourly forecast data. Falls back to `false` (high left) when hourly data is unavailable.
    func lowBeforeHigh(for day: DailyForecast) -> Bool {
        let hours = hourlyForecasts(for: day)
        guard !hours.isEmpty else { return false }
        guard let minHour = hours.min(by: { $0.airTemperature < $1.airTemperature }),
              let maxHour = hours.max(by: { $0.airTemperature < $1.airTemperature }) else { return false }
        return minHour.localHour < maxHour.localHour
    }

    var todayLowBeforeHigh: Bool {
        guard let today = forecastResponse?.forecast.daily.first else { return false }
        return lowBeforeHigh(for: today)
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
        let requested = selection
        do {
            let response: ForecastResponse
            switch requested {
            case .station:
                response = try await TempestAPIService().fetchForecast()
            case .currentLocation:
                let location = try await locationService.currentLocation()
                let place = try? await locationService.placeDetails(for: location)
                response = try await weatherKitService.fetchForecast(
                    for: location,
                    name: place?.name ?? "Current Location",
                    timeZone: place?.timeZone ?? .current
                )
            case .saved(let id):
                guard let saved = savedLocations.first(where: { $0.id == id }) else {
                    throw LocationSelectionError.missing
                }
                response = try await weatherKitService.fetchForecast(
                    for: saved.location, name: saved.name, timeZone: saved.timeZone
                )
            }
            // Ignore results for a location the user has already switched away from.
            guard requested == selection else { return }
            forecastResponse = response
            lastUpdated = Date()
        } catch {
            if requested == selection { errorMessage = error.localizedDescription }
        }
        if requested == selection { isLoading = false }
    }

    // MARK: - Location management

    /// Switches the dashboard to another location and refreshes it.
    /// Starts the WebSocket for the station; stops it for anything else.
    /// - Parameter newSelection: The location to show.
    func select(_ newSelection: LocationSelection) async {
        guard newSelection != selection else { return }
        selection = newSelection
        persistSelection()
        forecastResponse = nil
        lastUpdated = nil
        if newSelection == .station {
            startWebSocket()
        } else {
            stopWebSocket()
        }
        await refresh()
    }

    /// Adds a location to the saved list and selects it.
    /// - Parameter location: The location to add.
    func add(_ location: SavedLocation) async {
        savedLocations.append(location)
        persistSavedLocations()
        await select(.saved(location.id))
    }

    /// Removes saved locations; falls back to the station if the selected one is removed.
    /// - Parameter ids: Identifiers of the locations to remove.
    func removeLocations(_ ids: Set<UUID>) async {
        savedLocations.removeAll { ids.contains($0.id) }
        persistSavedLocations()
        if case .saved(let id) = selection, ids.contains(id) {
            await select(.station)
        }
    }

    /// Display name for a location in lists.
    /// - Parameter selection: The location to name.
    /// - Returns: The station's name, "Current Location", or the saved name.
    func displayName(for selection: LocationSelection) -> String {
        switch selection {
        case .station:
            if isStationSelected, let name = forecastResponse?.locationName { return name }
            return "My Station"
        case .currentLocation:
            return "Current Location"
        case .saved(let id):
            return savedLocations.first(where: { $0.id == id })?.name ?? "Unknown"
        }
    }

    /// Looks up a place name and time zone for a coordinate picked on the map.
    /// - Parameter location: Coordinates to look up.
    /// - Returns: The place name and time zone, either of which may be `nil`.
    /// - Throws: The underlying geocoding error.
    func placeDetails(for location: CLLocation) async throws -> PlaceDetails {
        try await locationService.placeDetails(for: location)
    }

    /// Fetches the Apple Weather attribution shown with WeatherKit data.
    /// - Returns: The attribution logos and legal page link.
    /// - Throws: The underlying WeatherKit error.
    func weatherAttribution() async throws -> WeatherAttribution {
        try await weatherKitService.attribution()
    }

    private func persistSelection() {
        do {
            try locationStore.saveSelection(selection)
        } catch {
            Self.logger.error("Could not save selection: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your location choice could not be saved."
        }
    }

    private func persistSavedLocations() {
        do {
            try locationStore.saveSavedLocations(savedLocations)
        } catch {
            Self.logger.error("Could not save locations: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your saved locations could not be saved."
        }
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
        guard isStationSelected,
              let token = TempestAPIService.loadApiToken(),
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
        clearLiveValues()
    }

    /// Drops live readings so they can't override another location's data.
    private func clearLiveValues() {
        liveWindSpeedMps = nil
        liveWindGustMps = nil
        liveWindDirectionDeg = nil
        liveAirTempC = nil
        liveHumidity = nil
        livePressureMb = nil
        liveUV = nil
        livePrecipDayMm = nil
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

// MARK: - Errors

/// Errors raised when the selected location can't be resolved.
enum LocationSelectionError: LocalizedError {
    case missing

    var errorDescription: String? { "The selected location no longer exists." }
}

// MARK: - Array helper

private extension Array where Element == Double? {
    subscript(safe index: Int) -> Double? {
        guard index < count else { return nil }
        return self[index]
    }
}
