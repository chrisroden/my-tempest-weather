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
- **Device ID** → `UserDefaults` key `"WeatherFlow.deviceId"` (required for WebSocket subscriptions)
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
    │   ├── TempestAPIService.swift      // REST client + Keychain + UserDefaults
    │   └── TempestWebSocketService.swift // Real-time WebSocket stream, rapid_wind + obs_st
    ├── ViewModels/
    │   └── WeatherViewModel.swift       // @Observable, auto-refresh timer
    ├── Views/
    │   ├── ContentView.swift            // TabView (iPhone) / NavigationSplitView (iPad/Mac)
    │   ├── DashboardView.swift          // 2-col LazyVGrid, refresh toolbar
    │   ├── CurrentConditionsView.swift  // Temp, icon, feels-like/high/low
    │   ├── WindView.swift               // SwiftUI compass rose + speed/gust/cardinal
    │   ├── MetricsView.swift            // Humidity, pressure, UV, precip, lightning
    │   ├── ForecastView.swift           // Horizontal 7-day strip + collapsible hourly row
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
- `startWebSocket()` / `stopWebSocket()` — creates a `TempestWebSocketService`, wires its callbacks, and calls `connect(token:deviceId:)`
- `isWebSocketConnected: Bool` — reflects live connection state from `onConnectionChange`
- Display properties (`currentTemperature`, `windSpeed`, `windGust`, `windDirection`, `relativeHumidity`, `seaLevelPressure`, `uvIndex`, `precipAccumLocalDay`) prefer **live WebSocket values** when available, falling back to the last REST response
- All display properties (`dailyForecasts`, `feelsLike`, `todayHigh/Low`, etc.) that have no WebSocket equivalent are computed from `forecastResponse`
- `hourlyForecasts(for day: DailyForecast) -> [HourlyForecast]` — filters `forecast.hourly` where `localDay == day.dayNum`

### TempestAPIService

- `static func saveApiToken(_ token: String)` — writes to Keychain
- `static func loadApiToken() -> String?` — reads from Keychain
- `static func deleteApiToken()` — deletes from Keychain
- `static var stationId: Int` — get/set via `UserDefaults` (`"WeatherFlow.stationId"`)
- `static var deviceId: Int` — get/set via `UserDefaults` (`"WeatherFlow.deviceId"`); required for WebSocket subscriptions
- `func fetchForecast() async throws -> ForecastResponse` — builds URL, calls `URLSession.shared.data(for:)`, decodes JSON

### TempestWebSocketService

Connects to the WeatherFlow real-time WebSocket stream (`wss://ws.weatherflow.com/swd/data?token={token}`).

- `connect(token:deviceId:)` / `disconnect()` — start/stop the connection
- Subscribes to two channels on connection open:
  - `listen_rapid_start` — wind speed + direction every ~3 s (`rapid_wind` event)
  - `listen_start` — full station observation every ~1 min (`obs_st` event)
- Exposes three callbacks (always delivered on `MainActor`):
  - `onRapidWind: (speedMps: Double, directionDeg: Int) -> Void`
  - `onObsSt: ([Double?]) -> Void` — obs array indices: `[3]` gust, `[6]` pressure, `[7]` air temp °C, `[8]` humidity, `[10]` UV, `[18]` precip day mm
  - `onConnectionChange: (Bool) -> Void`
- Sends a `ping` message every 30 s to keep the connection alive
- Reconnects with exponential back-off (2 s → 4 s → … → 60 s cap) on any error or delegate-initiated close
- `isConnected: Bool` — read-only published state

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
- [x] **iPad/Mac layout polish** — `ContentView` uses `NavigationSplitView` with `List(selection:)` sidebar; selecting Settings pushes `SettingsView` into the detail column.
- [x] **Unit preferences UI** — `SettingsView` now exposes pickers for temperature, wind speed, pressure, and precipitation units, saved to `UserDefaults` and used by the next REST fetch.
- [x] **Hourly forecast** — Tap any `DayCard` in `ForecastView` to expand a collapsible `HourlyStrip` below the day row; tap the same card again to collapse. Animated with `.easeInOut(duration: 0.3)` + `.move(edge: .top).combined(with: .opacity)` transition.
- [ ] **Widgets / Live Activities** — not yet implemented.
- [x] **Dark mode accent** — dark variant `#5BB8FF` (r:0.357, g:0.722, b:1.000) added to `AccentColor.colorset` with `luminosity: dark` appearance.

---

## Git remotes

| Remote | URL |
|--------|-----|
| `origin` | `https://github.com/chrisroden/my-tempest-weather.git` |
| `ado` | `https://chrisroden@dev.azure.com/chrisroden/Tempest%20Weather%20Station%20Console/_git/my-tempest-weather` |

Push to both remotes when shipping changes:
```bash
git push origin
git push ado
```

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
- New daily forecast rows follow the `DayRow` private struct pattern in `ForecastView.swift`.
- New hourly forecast cards follow the `HourCard` private struct pattern in `ForecastView.swift`.
