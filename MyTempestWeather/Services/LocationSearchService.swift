import Foundation
import MapKit
import Observation
import os

/// Wraps `MKLocalSearchCompleter` for place search and `MKLocalSearch` to get coordinates.
@Observable
@MainActor
final class LocationSearchService: NSObject, ILocationSearchService {

    private static let logger = Logger(subsystem: "com.chrisroden.MyTempestWeather", category: "LocationSearchService")

    /// Completions matching the latest query.
    private(set) var results: [MKLocalSearchCompletion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    /// Creates the service, limited to addresses (cities, towns, postcodes).
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    /// Updates the search text; `results` refreshes asynchronously.
    /// - Parameter query: Text typed by the user.
    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            results = []
        }
        completer.queryFragment = trimmed
    }

    /// Resolves a completion to coordinates.
    /// - Parameter completion: A completion from `results`.
    /// - Returns: A location ready to save.
    /// - Throws: The underlying MapKit error, or `LocationSearchError.noResult`.
    func resolve(_ completion: MKLocalSearchCompletion) async throws -> SavedLocation {
        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            guard let item = response.mapItems.first else { throw LocationSearchError.noResult }
            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26.0, *) {
                coordinate = item.location.coordinate
            } else {
                coordinate = item.placemark.coordinate
            }
            return SavedLocation(name: completion.title,
                                 latitude: coordinate.latitude,
                                 longitude: coordinate.longitude,
                                 timeZoneIdentifier: item.timeZone?.identifier)
        } catch {
            Self.logger.error("Place search failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results
        MainActor.assumeIsolated { results = completions }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            Self.logger.error("Search completer failed: \(error.localizedDescription, privacy: .public)")
            results = []
        }
    }
}

// MARK: - Errors

/// Errors raised by `LocationSearchService`.
enum LocationSearchError: LocalizedError {
    case noResult

    var errorDescription: String? { "No matching place was found." }
}
