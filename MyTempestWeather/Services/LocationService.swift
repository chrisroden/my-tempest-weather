import Foundation
import CoreLocation
import MapKit
import os

/// Wraps `CLLocationManager` for one-shot location fixes, plus reverse geocoding for place names.
@MainActor
final class LocationService: NSObject, ILocationService {

    private static let logger = Logger(subsystem: "com.chrisroden.MyTempestWeather", category: "LocationService")

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    /// Creates the service. City-level accuracy is enough for weather.
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Requests when-in-use permission if needed and returns a single location fix.
    /// - Returns: The device's current location.
    /// - Throws: `LocationServiceError` if permission is refused or a request is already running,
    ///   or the underlying Core Location error.
    func currentLocation() async throws -> CLLocation {
        var status = manager.authorizationStatus
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationServiceError.denied
        }
        guard locationContinuation == nil else { throw LocationServiceError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Looks up a short place name (e.g. "Denton, TX") and time zone for a coordinate.
    /// - Parameter location: Coordinates to look up.
    /// - Returns: The place name and time zone; either may be `nil` if the lookup found nothing.
    /// - Throws: The underlying geocoding error.
    func placeDetails(for location: CLLocation) async throws -> PlaceDetails {
        do {
            if #available(iOS 26.0, *) {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    return PlaceDetails(name: nil, timeZone: nil)
                }
                let item = try await request.mapItems.first
                return PlaceDetails(name: item?.addressRepresentations?.cityWithContext ?? item?.name,
                                    timeZone: item?.timeZone)
            } else {
                let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
                let name = [placemark?.locality, placemark?.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                    .nilIfEmpty ?? placemark?.name
                return PlaceDetails(name: name, timeZone: placemark?.timeZone)
            }
        } catch {
            Self.logger.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard status != .notDetermined, let continuation = authorizationContinuation else { return }
            authorizationContinuation = nil
            continuation.resume(returning: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            Self.logger.error("Location request failed: \(error.localizedDescription, privacy: .public)")
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}

// MARK: - Errors

/// Errors raised by `LocationService`.
enum LocationServiceError: LocalizedError {
    case denied
    case busy

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access is off. Turn it on in Settings to use Current Location."
        case .busy:   return "A location request is already in progress."
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
