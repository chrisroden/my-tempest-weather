import Foundation
import CoreLocation
import WeatherKit

/// Fetches weather for arbitrary coordinates from Apple WeatherKit.
protocol IWeatherKitService {
    /// Fetches current conditions plus daily and hourly forecasts, mapped into the
    /// app's `ForecastResponse` model in the user's chosen display units.
    /// - Parameters:
    ///   - location: Coordinates to fetch weather for.
    ///   - name: Display name to use as the response's `locationName`.
    ///   - timeZone: The location's time zone, used for day and hour labels.
    /// - Returns: A `ForecastResponse` the existing views can render.
    /// - Throws: The underlying WeatherKit error.
    func fetchForecast(for location: CLLocation, name: String, timeZone: TimeZone) async throws -> ForecastResponse

    /// Fetches the Apple Weather attribution that must be shown alongside WeatherKit data.
    /// - Returns: The attribution logos and legal page link.
    /// - Throws: The underlying WeatherKit error.
    func attribution() async throws -> WeatherAttribution
}
