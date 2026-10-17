import Foundation
import MapKit

/// Type-ahead place search for adding new locations.
@MainActor
protocol ILocationSearchService: AnyObject {
    /// Completions matching the latest query.
    var results: [MKLocalSearchCompletion] { get }

    /// Updates the search text; `results` refreshes asynchronously.
    /// - Parameter query: Text typed by the user.
    func update(query: String)

    /// Resolves a completion to coordinates.
    /// - Parameter completion: A completion from `results`.
    /// - Returns: A location ready to save.
    /// - Throws: The underlying MapKit error, or `LocationSearchError.noResult`.
    func resolve(_ completion: MKLocalSearchCompletion) async throws -> SavedLocation
}
