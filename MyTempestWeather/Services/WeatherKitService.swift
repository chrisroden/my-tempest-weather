import Foundation
import CoreLocation
import WeatherKit
import os

/// Fetches weather for non-station locations from WeatherKit and maps it into the
/// app's Tempest-shaped `ForecastResponse`, so the existing views render it unchanged.
/// Values are converted to the user's display units (the same `WeatherFlow.*Units` prefs
/// the Tempest REST call uses), and icons are mapped to WeatherFlow icon slugs.
struct WeatherKitService: IWeatherKitService {

    private static let logger = Logger(subsystem: "com.chrisroden.MyTempestWeather", category: "WeatherKitService")

    /// Number of days of hourly forecast to request (matches the daily forecast length).
    private static let hourlyDays = 10

    /// Fetches current conditions plus daily and hourly forecasts, mapped into the
    /// app's `ForecastResponse` model in the user's chosen display units.
    /// - Parameters:
    ///   - location: Coordinates to fetch weather for.
    ///   - name: Display name to use as the response's `locationName`.
    ///   - timeZone: The location's time zone, used for day and hour labels.
    /// - Returns: A `ForecastResponse` the existing views can render.
    /// - Throws: The underlying WeatherKit error.
    func fetchForecast(for location: CLLocation, name: String, timeZone: TimeZone) async throws -> ForecastResponse {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(Self.hourlyDays * 86_400))
        do {
            let (current, hourly, daily) = try await WeatherService.shared.weather(
                for: location,
                including: .current, .hourly(startDate: now, endDate: end), .daily
            )
            let units = DisplayUnits.current
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone

            let days = daily.forecast.map { mapDay($0, units: units, calendar: calendar) }
            let hours = hourly.forecast.map { mapHour($0, units: units, calendar: calendar) }
            let todayPrecip = daily.forecast.first.map { precipitationAmount(of: $0) }

            return ForecastResponse(
                currentConditions: mapCurrent(current, todayPrecip: todayPrecip, units: units),
                forecast: Forecast(daily: days, hourly: hours),
                latitude: location.coordinate.latitude,
                locationName: name,
                longitude: location.coordinate.longitude,
                timezone: timeZone.identifier,
                timezoneOffsetMinutes: timeZone.secondsFromGMT() / 60,
                units: units.asUnits,
                station: Station(agl: 0, elevation: 0, isStationOnline: false, stationId: 0),
                status: Status(statusCode: 0, statusMessage: "SUCCESS")
            )
        } catch {
            Self.logger.error("WeatherKit fetch failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Fetches the Apple Weather attribution that must be shown alongside WeatherKit data.
    /// - Returns: The attribution logos and legal page link.
    /// - Throws: The underlying WeatherKit error.
    func attribution() async throws -> WeatherAttribution {
        do {
            return try await WeatherService.shared.attribution
        } catch {
            Self.logger.error("WeatherKit attribution failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Mapping

    private func mapCurrent(_ c: CurrentWeather, todayPrecip: Measurement<UnitLength>?, units: DisplayUnits) -> CurrentConditions {
        CurrentConditions(
            airDensity: 0,
            airTemperature: c.temperature.converted(to: units.temperature).value,
            brightness: 0,
            conditions: c.condition.description,
            deltaT: 0,
            dewPoint: c.dewPoint.converted(to: units.temperature).value,
            feelsLike: c.apparentTemperature.converted(to: units.temperature).value,
            icon: Self.iconSlug(for: c.condition, isDaylight: c.isDaylight),
            lightningStrikeCountLast1hr: 0,
            lightningStrikeCountLast3hr: 0,
            lightningStrikeLastDistance: 0,
            lightningStrikeLastDistanceMsg: "",
            lightningStrikeLastEpoch: 0,
            precipAccumLocalDay: todayPrecip?.converted(to: units.precipitation).value ?? 0,
            precipAccumLocalYesterday: 0,
            precipMinutesLocalDay: 0,
            precipMinutesLocalYesterday: 0,
            pressureTrend: c.pressureTrend.trendName,
            relativeHumidity: Int((c.humidity * 100).rounded()),
            seaLevelPressure: c.pressure.converted(to: units.pressure).value,
            solarRadiation: 0,
            stationPressure: 0,
            time: Int(c.date.timeIntervalSince1970),
            uv: Double(c.uvIndex.value),
            wetBulbGlobeTemperature: 0,
            wetBulbTemperature: 0,
            windAvg: c.wind.speed.converted(to: units.wind).value,
            windDirection: Int(c.wind.direction.converted(to: .degrees).value.rounded()),
            windDirectionCardinal: c.wind.compassDirection.abbreviation,
            windGust: c.wind.gust?.converted(to: units.wind).value ?? 0
        )
    }

    private func mapDay(_ d: DayWeather, units: DisplayUnits, calendar: Calendar) -> DailyForecast {
        DailyForecast(
            airTempHigh: d.highTemperature.converted(to: units.temperature).value,
            airTempLow: d.lowTemperature.converted(to: units.temperature).value,
            conditions: d.condition.description,
            dayNum: calendar.component(.day, from: d.date),
            dayStartLocal: Int(d.date.timeIntervalSince1970),
            icon: Self.iconSlug(for: d.condition, isDaylight: true),
            monthNum: calendar.component(.month, from: d.date),
            precipIcon: "",
            precipProbability: Int((d.precipitationChance * 100).rounded()),
            precipType: d.precipitation.rawValue,
            sunrise: d.sun.sunrise.map { Int($0.timeIntervalSince1970) } ?? 0,
            sunset: d.sun.sunset.map { Int($0.timeIntervalSince1970) } ?? 0,
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }

    private func mapHour(_ h: HourWeather, units: DisplayUnits, calendar: Calendar) -> HourlyForecast {
        HourlyForecast(
            airTemperature: h.temperature.converted(to: units.temperature).value,
            conditions: h.condition.description,
            feelsLike: h.apparentTemperature.converted(to: units.temperature).value,
            icon: Self.iconSlug(for: h.condition, isDaylight: h.isDaylight),
            localDay: calendar.component(.day, from: h.date),
            localHour: calendar.component(.hour, from: h.date),
            precip: h.precipitationAmount.converted(to: units.precipitation).value,
            precipIcon: "",
            precipProbability: (h.precipitationChance * 100).rounded(),
            precipType: h.precipitation.rawValue,
            relativeHumidity: Int((h.humidity * 100).rounded()),
            seaLevelPressure: h.pressure.converted(to: units.pressure).value,
            time: Int(h.date.timeIntervalSince1970),
            uv: Double(h.uvIndex.value),
            windAvg: h.wind.speed.converted(to: units.wind).value,
            windDirection: Int(h.wind.direction.converted(to: .degrees).value.rounded()),
            windDirectionCardinal: h.wind.compassDirection.abbreviation,
            windGust: h.wind.gust?.converted(to: units.wind).value ?? 0,
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }

    private func precipitationAmount(of day: DayWeather) -> Measurement<UnitLength> {
        if #available(iOS 18.0, *) {
            return day.precipitationAmountByType.precipitation
        } else {
            return day.precipitationAmount
        }
    }

    /// Maps a WeatherKit condition to the closest WeatherFlow icon slug, so
    /// `String.sfSymbol` and `WeatherIconView` work unchanged.
    static func iconSlug(for condition: WeatherCondition, isDaylight: Bool) -> String {
        let period = isDaylight ? "day" : "night"
        switch condition {
        case .clear, .mostlyClear, .hot, .frigid:
            return "clear-\(period)"
        case .partlyCloudy:
            return "partly-cloudy-\(period)"
        case .mostlyCloudy, .cloudy:
            return "cloudy"
        case .foggy, .haze, .smoky, .blowingDust:
            return "foggy"
        case .sunShowers:
            return "possibly-rainy-\(period)"
        case .drizzle, .rain, .heavyRain:
            return "rainy"
        case .freezingDrizzle, .freezingRain, .sleet, .wintryMix, .hail:
            return "sleet"
        case .flurries, .sunFlurries:
            return "possibly-snow-\(period)"
        case .snow, .heavySnow, .blizzard, .blowingSnow:
            return "snow"
        case .isolatedThunderstorms, .scatteredThunderstorms:
            return "possibly-thunderstorm-\(period)"
        case .thunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return "thunderstorm"
        case .breezy, .windy:
            return "windy"
        @unknown default:
            return "cloudy"
        }
    }
}

// MARK: - Display units

/// The user's display-unit preferences, resolved to Foundation units.
private struct DisplayUnits {
    let tempKey: String
    let windKey: String
    let pressureKey: String
    let precipKey: String

    static var current: DisplayUnits {
        let defaults = UserDefaults.standard
        return DisplayUnits(
            tempKey:     defaults.string(forKey: "WeatherFlow.tempUnits")     ?? "f",
            windKey:     defaults.string(forKey: "WeatherFlow.windUnits")     ?? "mph",
            pressureKey: defaults.string(forKey: "WeatherFlow.pressureUnits") ?? "mb",
            precipKey:   defaults.string(forKey: "WeatherFlow.precipUnits")   ?? "in"
        )
    }

    var temperature: UnitTemperature { tempKey == "c" ? .celsius : .fahrenheit }

    var wind: UnitSpeed {
        switch windKey {
        case "kph": return .kilometersPerHour
        case "kts": return .knots
        case "mps": return .metersPerSecond
        default:    return .milesPerHour
        }
    }

    var pressure: UnitPressure {
        switch pressureKey {
        case "hpa":  return .hectopascals
        case "inhg": return .inchesOfMercury
        case "mmhg": return .millimetersOfMercury
        default:     return .millibars
        }
    }

    var precipitation: UnitLength { precipKey == "mm" ? .millimeters : .inches }

    var asUnits: Units {
        Units(unitsAirDensity: "", unitsBrightness: "", unitsDistance: "", unitsOther: "",
              unitsPrecip: precipKey, unitsPressure: pressureKey, unitsSolarRadiation: "",
              unitsTemp: tempKey, unitsWind: windKey)
    }
}

// MARK: - Pressure trend

private extension PressureTrend {
    /// Matches the strings `MetricsView` checks for.
    var trendName: String {
        switch self {
        case .rising:  return "rising"
        case .falling: return "falling"
        case .steady:  return "steady"
        @unknown default: return "steady"
        }
    }
}
