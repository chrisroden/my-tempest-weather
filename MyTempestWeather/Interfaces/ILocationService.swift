import Foundation
import CoreLocation

/// Provides the device's location and turns coordinates into place details.
@MainActor
protocol ILocationService {
    /// Requests when-in-use permission if needed and returns a single location fix.
    /// - Returns: The device's current location.
    /// - Throws: `LocationServiceError` if permission is refused or a request is already running,
    ///   or the underlying Core Location error.
    func currentLocation() async throws -> CLLocation

    /// Looks up a short place name (e.g. "Denton, TX") and time zone for a coordinate.
    /// - Parameter location: Coordinates to look up.
    /// - Returns: The place name and time zone; either may be `nil` if the lookup found nothing.
    /// - Throws: The underlying geocoding error.
    func placeDetails(for location: CLLocation) async throws -> PlaceDetails
}

/// Result of a reverse geocode.
struct PlaceDetails {
    let name: String?
    let timeZone: TimeZone?
}
