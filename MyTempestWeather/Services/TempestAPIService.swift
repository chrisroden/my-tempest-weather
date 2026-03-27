import Foundation
import Security

/// Calls the WeatherFlow Better Forecast REST endpoint.
/// API token is persisted in the Keychain; station ID and unit prefs in UserDefaults.
struct TempestAPIService {

    // MARK: - UserDefaults keys

    private enum DefaultsKey {
        static let stationId = "WeatherFlow.stationId"
        static let tempUnits = "WeatherFlow.tempUnits"
        static let windUnits = "WeatherFlow.windUnits"
        static let pressureUnits = "WeatherFlow.pressureUnits"
        static let precipUnits = "WeatherFlow.precipUnits"
        static let distanceUnits = "WeatherFlow.distanceUnits"
    }

    // MARK: - Keychain key

    private static let keychainService = "com.chrisroden.MyTempestWeather"
    private static let keychainAccount = "WeatherFlowApiToken"

    // MARK: - Keychain helpers

    static func saveApiToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadApiToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    static func deleteApiToken() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - UserDefaults accessors

    static var stationId: Int {
        get { UserDefaults.standard.integer(forKey: DefaultsKey.stationId) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.stationId) }
    }

    // MARK: - Fetch forecast

    func fetchForecast() async throws -> ForecastResponse {
        guard let token = TempestAPIService.loadApiToken(), !token.isEmpty else {
            throw TempestAPIError.missingCredentials("API token not configured")
        }
        let stationId = TempestAPIService.stationId
        guard stationId > 0 else {
            throw TempestAPIError.missingCredentials("Station ID not configured")
        }

        let tempUnits     = UserDefaults.standard.string(forKey: DefaultsKey.tempUnits)     ?? "f"
        let windUnits     = UserDefaults.standard.string(forKey: DefaultsKey.windUnits)     ?? "mph"
        let pressureUnits = UserDefaults.standard.string(forKey: DefaultsKey.pressureUnits) ?? "mb"
        let precipUnits   = UserDefaults.standard.string(forKey: DefaultsKey.precipUnits)   ?? "in"
        let distanceUnits = UserDefaults.standard.string(forKey: DefaultsKey.distanceUnits) ?? "mi"

        var components = URLComponents(string: "https://swd.weatherflow.com/swd/rest/better_forecast")!
        components.queryItems = [
            URLQueryItem(name: "station_id",       value: "\(stationId)"),
            URLQueryItem(name: "units_temp",       value: tempUnits),
            URLQueryItem(name: "units_wind",       value: windUnits),
            URLQueryItem(name: "units_pressure",   value: pressureUnits),
            URLQueryItem(name: "units_precip",     value: precipUnits),
            URLQueryItem(name: "units_distance",   value: distanceUnits),
            URLQueryItem(name: "token",            value: token)
        ]

        guard let url = components.url else {
            throw TempestAPIError.invalidURL
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TempestAPIError.unexpectedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TempestAPIError.httpError(httpResponse.statusCode, body)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        do {
            return try decoder.decode(ForecastResponse.self, from: data)
        } catch {
            throw TempestAPIError.decodingFailed(error)
        }
    }
}

// MARK: - Error types

enum TempestAPIError: LocalizedError {
    case missingCredentials(String)
    case invalidURL
    case unexpectedResponse
    case httpError(Int, String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingCredentials(let msg): return msg
        case .invalidURL:                  return "Could not build request URL."
        case .unexpectedResponse:          return "Unexpected server response."
        case .httpError(let code, let body):
            return "Server returned \(code): \(body.prefix(200))"
        case .decodingFailed(let err):
            return "Data decoding failed: \(err.localizedDescription)"
        }
    }
}
