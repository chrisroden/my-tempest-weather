import Foundation
import os

/// Stores saved locations and the current selection in `UserDefaults` as JSON.
struct LocationStore: ILocationStore {

    // MARK: - UserDefaults keys

    private enum DefaultsKey {
        static let savedLocations = "WeatherFlow.savedLocations"
        static let selection      = "WeatherFlow.selectedLocation"
    }

    private static let logger = Logger(subsystem: "com.chrisroden.MyTempestWeather", category: "LocationStore")

    private let defaults: UserDefaults

    /// Creates a store backed by the given defaults.
    /// - Parameter defaults: Defaults to read and write; `.standard` by default.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Loads saved locations in display order.
    /// - Returns: The saved locations, or an empty array if none are stored.
    /// - Throws: A decoding error if stored data is corrupt.
    func loadSavedLocations() throws -> [SavedLocation] {
        try decode([SavedLocation].self, forKey: DefaultsKey.savedLocations) ?? []
    }

    /// Replaces the stored saved locations.
    /// - Parameter locations: Locations to store, in display order.
    /// - Throws: An encoding error if the locations can't be serialised.
    func saveSavedLocations(_ locations: [SavedLocation]) throws {
        try encode(locations, forKey: DefaultsKey.savedLocations)
    }

    /// Loads the last selected location.
    /// - Returns: The stored selection, or `.station` if none is stored.
    /// - Throws: A decoding error if stored data is corrupt.
    func loadSelection() throws -> LocationSelection {
        try decode(LocationSelection.self, forKey: DefaultsKey.selection) ?? .station
    }

    /// Stores the selected location.
    /// - Parameter selection: The selection to store.
    /// - Throws: An encoding error if the selection can't be serialised.
    func saveSelection(_ selection: LocationSelection) throws {
        try encode(selection, forKey: DefaultsKey.selection)
    }

    // MARK: - JSON helpers

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Self.logger.error("Could not decode \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) throws {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            Self.logger.error("Could not encode \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
