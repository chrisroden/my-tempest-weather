# Copilot Context — My Tempest Weather

## What this project is

This is a native Apple multiplatform app called **My Tempest Weather**, targeting iOS 17+, iPadOS 17+, and macOS 14+ (via Mac Catalyst). It was created from scratch as the Apple counterpart to an existing .NET/Avalonia project located at `~/Repos/Personal/tempest-weather-pi-console/`.

The Apple app calls the **WeatherFlow Tempest REST API directly** — it does not depend on the Pi backend in any way.

---

## Source project (for reference only, do not modify)

`~/Repos/Personal/tempest-weather-pi-console/` is a .NET 9 / C# project with:
- `Tempest.REST` — REST API client for WeatherFlow
- `Tempest.WebSocket` — real-time WebSocket listener
- `Tempest.UI` — Avalonia desktop UI (Raspberry Pi kiosk), MVVM via CommunityToolkit.Mvvm
- `TempestBlazorApp` — Blazor Server + SignalR hub (runs on the Pi)

The Apple app mirrors the same data display as the Avalonia UI but without the two-tier architecture.

---

## WeatherFlow REST API

```
GET https://swd.weatherflow.com/swd/rest/better_forecast
  ?station_id={id}
  &units_temp=f
  &units_wind=mph
  &units_pressure=mb
  &units_precip=in
  &units_distance=mi
  &token={token}
```

Credentials are stored securely:
- **API token** → iOS Keychain (`service: "com.chrisroden.MyTempestWeather"`, `account: "WeatherFlowApiToken"`)
- **Station ID** → `UserDefaults` key `"WeatherFlow.stationId"`
- **Refresh interval** → `UserDefaults` key `"WeatherFlow.refreshIntervalMinutes"` (default: 5)

---

## Tech stack

| Concern | Choice |
|---------|--------|
| Language | Swift 5.9+ |
| UI framework | SwiftUI |
| State management | `@Observable` macro (iOS 17+) |
| Networking | `URLSession` (no third-party libs) |
| Secure storage | Keychain via `Security` framework |
| Icons | SF Symbols (mapped from WeatherFlow icon slugs) |
| Platforms | `TARGETED_DEVICE_FAMILY = "1,2"`, `SUPPORTS_MACCATALYST = YES` |
| Deployment targets | iOS 17.0, macOS 14.0 |
| Bundle ID | `com.chrisroden.MyTempestWeather` |

---

## Project structure

```
my-tempest-weather/
├── MyTempestWeather.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/
│       └── contents.xcworkspacedata
└── MyTempestWeather/
    ├── MyTempestWeatherApp.swift        // @main entry point
    ├── Models/
    │   └── WeatherModels.swift          // All Codable models + SF Symbol mapping
    ├── Services/
    │   └── TempestAPIService.swift      // REST client + Keychain + UserDefaults
    ├── ViewModels/
    │   └── WeatherViewModel.swift       // @Observable, auto-refresh timer
    ├── Views/
    │   ├── ContentView.swift            // TabView (iPhone) / NavigationSplitView (iPad/Mac)
    │   ├── DashboardView.swift          // 2-col LazyVGrid, refresh toolbar
    │   ├── CurrentConditionsView.swift  // Temp, icon, feels-like/high/low
    │   ├── WindView.swift               // SwiftUI compass rose + speed/gust/cardinal
    │   ├── MetricsView.swift            // Humidity, pressure, UV, precip, lightning
    │   ├── ForecastView.swift           // Horizontal 7-day strip
    │   └── SettingsView.swift           // SecureField token, station ID, refresh picker
    ├── Assets.xcassets/
    │   ├── AccentColor.colorset/        // Sky blue (#219CF3)
    │   └── AppIcon.appiconset/          // Placeholder — needs a real icon image
    └── Preview Content/
        └── Preview Assets.xcassets/
```

---

## Key implementation details

### WeatherViewModel (`@Observable`)

- `isConfigured: Bool` — returns `true` when Keychain token exists and `stationId > 0`
- `refresh() async` — calls `TempestAPIService().fetchForecast()`, sets `forecastResponse`, `lastUpdated`, `errorMessage`
- `startAutoRefresh(intervalMinutes:)` / `stopAutoRefresh()` — manages a background `Task` with `Task.sleep`
- All display properties (`currentTemperature`, `windSpeed`, `dailyForecasts`, etc.) are computed from `forecastResponse`

### TempestAPIService

- `static func saveApiToken(_ token: String)` — writes to Keychain
- `static func loadApiToken() -> String?` — reads from Keychain
- `static func deleteApiToken()` — deletes from Keychain
- `static var stationId: Int` — get/set via `UserDefaults`
- `func fetchForecast() async throws -> ForecastResponse` — builds URL, calls `URLSession.shared.data(for:)`, decodes JSON

### WeatherModels

All models are `Codable` with `CodingKeys` for snake_case JSON. Key models:
- `ForecastResponse` — top-level JSON wrapper (`current_conditions`, `forecast`, `location_name`)
- `CurrentConditions` — 30+ properties matching the WeatherFlow API response
- `DailyForecast: Codable, Identifiable` — includes a `weekdayLabel` computed property using `DateFormatter`
- `String` extension — `sfSymbol` maps WeatherFlow icon slugs (e.g. `"clear-day"`) to SF Symbol names; `iconTint` returns the appropriate `Color`

### ContentView layout strategy

- **iPhone** (`UIDevice.current.userInterfaceIdiom == .phone`): `TabView` with Weather and Settings tabs
- **iPad / Mac**: `NavigationSplitView` with sidebar + detail

### SettingsView

- Uses `SecureField` for the API token (writes to Keychain on Save)
- Validates that station ID is a positive integer before saving
- Triggers an immediate `viewModel.refresh()` and restarts the auto-refresh timer after saving

---

## What still needs doing

- [ ] **App icon** — `Assets.xcassets/AppIcon.appiconset/` has a placeholder `Contents.json` only. A 1024×1024 PNG needs to be added and the `Contents.json` updated with the filename.
- [ ] **Signing** — Open in Xcode → Signing & Capabilities → set your Apple Developer Team.
- [ ] **iPad/Mac layout polish** — `ContentView` uses `NavigationSplitView` but the sidebar `NavigationLink` for Settings only pushes `DashboardView` in the detail column. The Settings link should push `SettingsView` into the detail column instead of (or in addition to) the toolbar sheet.
- [ ] **Unit preferences UI** — `WeatherViewModel` reads `UserDefaults` keys for `WeatherFlow.tempUnits`, `WeatherFlow.windUnits`, `WeatherFlow.pressureUnits`, `WeatherFlow.precipUnits` but `SettingsView` does not yet expose pickers for those. Currently they default to `f`, `mph`, `mb`, `in`.
- [ ] **Hourly forecast** — `HourlyForecast` model exists but there is no hourly view yet.
- [ ] **Widgets / Live Activities** — not yet implemented.
- [ ] **Dark mode accent** — only a single light-mode accent colour is defined. Consider adding a dark-mode variant in `AccentColor.colorset`.

---

## How to open and run

```bash
open ~/Repos/Personal/my-tempest-weather/MyTempestWeather.xcodeproj
```

1. Select your simulator or device.
2. In **Signing & Capabilities**, set your Apple Developer Team.
3. Build and run (`⌘R`).
4. On first launch the Settings sheet appears automatically — enter your WeatherFlow API token and station ID.

---

## Conventions to follow for future changes

- Match the existing `@Observable` ViewModel pattern — no `@StateObject` or `ObservableObject`.
- All views receive the ViewModel via `@Environment(WeatherViewModel.self)`.
- No third-party Swift packages — stay within the Apple SDK.
- Secrets always go to Keychain; never `UserDefaults` for sensitive values.
- Unit symbols are derived from ViewModel computed properties (`tempUnitSymbol`, `windUnitSymbol`, etc.) — do not hardcode them in views.
- New metric tiles follow the `MetricTile` private struct pattern in `MetricsView.swift`.
- New forecast data follows the `DayCard` private struct pattern in `ForecastView.swift`.
