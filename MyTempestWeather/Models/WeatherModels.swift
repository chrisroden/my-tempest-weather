import Foundation
import SwiftUI

// MARK: - Top-level response

struct ForecastResponse: Codable {
    let currentConditions: CurrentConditions
    let forecast: Forecast
    let latitude: Double
    let locationName: String
    let longitude: Double
    let timezone: String
    let timezoneOffsetMinutes: Int
    let units: Units
    let station: Station
    let status: Status

    enum CodingKeys: String, CodingKey {
        case currentConditions = "current_conditions"
        case forecast
        case latitude
        case locationName = "location_name"
        case longitude
        case timezone
        case timezoneOffsetMinutes = "timezone_offset_minutes"
        case units
        case station
        case status
    }
}

// MARK: - Current Conditions

struct CurrentConditions: Codable {
    let airDensity: Double
    let airTemperature: Double
    let brightness: Int
    let conditions: String
    let deltaT: Double
    let dewPoint: Double
    let feelsLike: Double
    let icon: String
    let lightningStrikeCountLast1hr: Int
    let lightningStrikeCountLast3hr: Int
    let lightningStrikeLastDistance: Int
    let lightningStrikeLastDistanceMsg: String
    let lightningStrikeLastEpoch: Int
    let precipAccumLocalDay: Double
    let precipAccumLocalYesterday: Double
    let precipMinutesLocalDay: Double
    let precipMinutesLocalYesterday: Double
    let pressureTrend: String
    let relativeHumidity: Int
    let seaLevelPressure: Double
    let solarRadiation: Int
    let stationPressure: Double
    let time: Int
    let uv: Double
    let wetBulbGlobeTemperature: Double
    let wetBulbTemperature: Double
    let windAvg: Double
    let windDirection: Int
    let windDirectionCardinal: String
    let windGust: Double

    enum CodingKeys: String, CodingKey {
        case airDensity = "air_density"
        case airTemperature = "air_temperature"
        case brightness
        case conditions
        case deltaT = "delta_t"
        case dewPoint = "dew_point"
        case feelsLike = "feels_like"
        case icon
        case lightningStrikeCountLast1hr = "lightning_strike_count_last_1hr"
        case lightningStrikeCountLast3hr = "lightning_strike_count_last_3hr"
        case lightningStrikeLastDistance = "lightning_strike_last_distance"
        case lightningStrikeLastDistanceMsg = "lightning_strike_last_distance_msg"
        case lightningStrikeLastEpoch = "lightning_strike_last_epoch"
        case precipAccumLocalDay = "precip_accum_local_day"
        case precipAccumLocalYesterday = "precip_accum_local_yesterday"
        case precipMinutesLocalDay = "precip_minutes_local_day"
        case precipMinutesLocalYesterday = "precip_minutes_local_yesterday"
        case pressureTrend = "pressure_trend"
        case relativeHumidity = "relative_humidity"
        case seaLevelPressure = "sea_level_pressure"
        case solarRadiation = "solar_radiation"
        case stationPressure = "station_pressure"
        case time
        case uv
        case wetBulbGlobeTemperature = "wet_bulb_globe_temperature"
        case wetBulbTemperature = "wet_bulb_temperature"
        case windAvg = "wind_avg"
        case windDirection = "wind_direction"
        case windDirectionCardinal = "wind_direction_cardinal"
        case windGust = "wind_gust"
    }
}

// MARK: - Forecast

struct Forecast: Codable {
    let daily: [DailyForecast]
    let hourly: [HourlyForecast]
}

// MARK: - Daily Forecast

struct DailyForecast: Codable, Identifiable {
    var id: Int { dayStartLocal }
    let airTempHigh: Double
    let airTempLow: Double
    let conditions: String
    let dayNum: Int
    let dayStartLocal: Int
    let icon: String
    let monthNum: Int
    let precipIcon: String
    let precipProbability: Int
    let precipType: String
    let sunrise: Int
    let sunset: Int

    enum CodingKeys: String, CodingKey {
        case airTempHigh = "air_temp_high"
        case airTempLow = "air_temp_low"
        case conditions
        case dayNum = "day_num"
        case dayStartLocal = "day_start_local"
        case icon
        case monthNum = "month_num"
        case precipIcon = "precip_icon"
        case precipProbability = "precip_probability"
        case precipType = "precip_type"
        case sunrise
        case sunset
    }

    /// Short weekday label derived from the epoch timestamp.
    var weekdayLabel: String {
        let date = Date(timeIntervalSince1970: TimeInterval(dayStartLocal))
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Hourly Forecast

struct HourlyForecast: Codable, Identifiable {
    var id: Int { time }
    let airTemperature: Double
    let conditions: String
    let feelsLike: Double
    let icon: String
    let localDay: Int
    let localHour: Int
    let precip: Double
    let precipIcon: String
    let precipProbability: Double
    let precipType: String
    let relativeHumidity: Int
    let seaLevelPressure: Double
    let time: Int
    let uv: Double
    let windAvg: Double
    let windDirection: Int
    let windDirectionCardinal: String
    let windGust: Double

    enum CodingKeys: String, CodingKey {
        case airTemperature = "air_temperature"
        case conditions
        case feelsLike = "feels_like"
        case icon
        case localDay = "local_day"
        case localHour = "local_hour"
        case precip
        case precipIcon = "precip_icon"
        case precipProbability = "precip_probability"
        case precipType = "precip_type"
        case relativeHumidity = "relative_humidity"
        case seaLevelPressure = "sea_level_pressure"
        case time
        case uv
        case windAvg = "wind_avg"
        case windDirection = "wind_direction"
        case windDirectionCardinal = "wind_direction_cardinal"
        case windGust = "wind_gust"
    }
}

// MARK: - Station

struct Station: Codable {
    let agl: Double
    let elevation: Double
    let isStationOnline: Bool
    let stationId: Int

    enum CodingKeys: String, CodingKey {
        case agl
        case elevation
        case isStationOnline = "is_station_online"
        case stationId = "station_id"
    }
}

// MARK: - Units

struct Units: Codable {
    let unitsAirDensity: String
    let unitsBrightness: String
    let unitsDistance: String
    let unitsOther: String
    let unitsPrecip: String
    let unitsPressure: String
    let unitsSolarRadiation: String
    let unitsTemp: String
    let unitsWind: String

    enum CodingKeys: String, CodingKey {
        case unitsAirDensity = "units_air_density"
        case unitsBrightness = "units_brightness"
        case unitsDistance = "units_distance"
        case unitsOther = "units_other"
        case unitsPrecip = "units_precip"
        case unitsPressure = "units_pressure"
        case unitsSolarRadiation = "units_solar_radiation"
        case unitsTemp = "units_temp"
        case unitsWind = "units_wind"
    }
}

// MARK: - Status

struct Status: Codable {
    let statusCode: Int?
    let statusMessage: String?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMessage = "status_message"
    }
}

// MARK: - Weather icon → SF Symbol mapping

extension String {
    /// Maps a WeatherFlow icon slug to a SwiftUI/SF Symbols name.
    var sfSymbol: String {
        switch self {
        case "clear-day":                   return "sun.max.fill"
        case "clear-night":                 return "moon.stars.fill"
        case "cloudy":                      return "cloud.fill"
        case "foggy":                       return "cloud.fog.fill"
        case "partly-cloudy-day":           return "cloud.sun.fill"
        case "partly-cloudy-night":         return "cloud.moon.fill"
        case "possibly-rainy-day",
             "possibly-rain-day":           return "cloud.sun.rain.fill"
        case "possibly-rainy-night",
             "possibly-rain-night":         return "cloud.moon.rain.fill"
        case "possibly-sleet-day":          return "cloud.sleet.fill"
        case "possibly-sleet-night":        return "cloud.sleet.fill"
        case "possibly-snow-day":           return "cloud.snow.fill"
        case "possibly-snow-night":         return "cloud.snow.fill"
        case "possibly-thunderstorm-day":   return "cloud.sun.bolt.fill"
        case "possibly-thunderstorm-night": return "cloud.moon.bolt.fill"
        case "rainy":                       return "cloud.rain.fill"
        case "sleet":                       return "cloud.sleet.fill"
        case "snow":                        return "snowflake"
        case "thunderstorm":                return "cloud.bolt.rain.fill"
        case "windy":                       return "wind"
        default:                            return "cloud.fill"
        }
    }

    /// Colour tint for the weather icon.
    var iconTint: Color {
        switch self {
        case "clear-day":                   return .yellow
        case "clear-night":                 return .indigo
        case "snow", "possibly-snow-day",
             "possibly-snow-night":         return .cyan
        case "thunderstorm",
             "possibly-thunderstorm-day",
             "possibly-thunderstorm-night": return .yellow
        default:                            return .blue
        }
    }
}
