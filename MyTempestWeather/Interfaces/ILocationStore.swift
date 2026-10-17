import Foundation

/// Persists the user's saved locations and current selection.
protocol ILocationStore {
    /// Loads saved locations in display order.
    /// - Returns: The saved locations, or an empty array if none are stored.
    /// - Throws: A decoding error if stored data is corrupt.
    func loadSavedLocations() throws -> [SavedLocation]

    /// Replaces the stored saved locations.
    /// - Parameter locations: Locations to store, in display order.
    /// - Throws: An encoding error if the locations can't be serialised.
    func saveSavedLocations(_ locations: [SavedLocation]) throws

    /// Loads the last selected location.
    /// - Returns: The stored selection, or `.station` if none is stored.
    /// - Throws: A decoding error if stored data is corrupt.
    func loadSelection() throws -> LocationSelection

    /// Stores the selected location.
    /// - Parameter selection: The selection to store.
    /// - Throws: An encoding error if the selection can't be serialised.
    func saveSelection(_ selection: LocationSelection) throws
}
