import SwiftUI

/// Renders a WeatherFlow icon slug using SF Symbol palette rendering
/// with enforced colors: clouds white, sun yellow, moon blue, rain blue,
/// lightning yellow, snow/wind white.
struct WeatherIconView: View {
    let slug: String
    let size: CGFloat

    var body: some View {
        let symbol = slug.sfSymbol

        if symbol == "cloud.bolt.rain.fill" {
            // Composite: bolt+rain share one palette layer in SF Symbols,
            // so overlay two icons to get yellow bolt + blue rain.
            ZStack {
                Image(systemName: "cloud.rain.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.clear, .blue)
                Image(systemName: "cloud.bolt.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .yellow)
            }
            .frame(width: size, height: size)
        } else {
            let colors = symbolPalette(for: symbol)
            Image(systemName: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.palette)
                .foregroundStyle(colors.primary, colors.secondary, colors.tertiary)
                .frame(width: size, height: size)
        }
    }

    // MARK: - Palette mapping

    /// Returns (primary, secondary, tertiary) colors for each SF Symbol.
    /// Layer order follows Apple's palette convention per symbol.
    private func symbolPalette(for symbol: String) -> (primary: Color, secondary: Color, tertiary: Color) {
        switch symbol {
        case "sun.max.fill":           return (.yellow, .yellow, .yellow)
        case "moon.stars.fill":        return (.blue,   .white,  .white)
        case "cloud.fill":             return (.white,  .white,  .white)
        case "cloud.fog.fill":         return (.white,  .gray,   .gray)
        case "cloud.sun.fill":         return (.white,  .yellow, .yellow)
        case "cloud.moon.fill":        return (.white,  .blue,   .blue)
        case "cloud.sun.rain.fill":    return (.white,  .yellow, .blue)
        case "cloud.moon.rain.fill":   return (.white,  .blue,   .blue)
        case "cloud.sleet.fill":       return (.white,  .blue,   .blue)
        case "cloud.snow.fill":        return (.white,  .white,  .white)
        case "cloud.bolt.fill":        return (.white,  .yellow, .yellow)
        case "cloud.rain.fill":        return (.white,  .blue,   .blue)
        case "snowflake":              return (.white,  .white,  .white)
        case "wind":                   return (.white,  .white,  .white)
        default:                       return (.white,  .white,  .white)
        }
    }
}

// MARK: - Preview

#Preview {
    let slugs: [(String, String)] = [
        ("clear-day", "Clear Day"),
        ("clear-night", "Clear Night"),
        ("cloudy", "Cloudy"),
        ("foggy", "Foggy"),
        ("partly-cloudy-day", "Partly Cloudy Day"),
        ("partly-cloudy-night", "Partly Cloudy Night"),
        ("rainy", "Rainy"),
        ("possibly-rainy-day", "Possible Rain Day"),
        ("possibly-rainy-night", "Possible Rain Night"),
        ("possibly-sleet-day", "Sleet"),
        ("possibly-snow-day", "Snow Day"),
        ("snow", "Snow"),
        ("possibly-thunderstorm-day", "Storm Day"),
        ("possibly-thunderstorm-night", "Storm Night"),
        ("thunderstorm", "Thunderstorm"),
        ("windy", "Windy"),
    ]

    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(slugs, id: \.0) { slug, label in
                HStack(spacing: 16) {
                    WeatherIconView(slug: slug, size: 64)
                    WeatherIconView(slug: slug, size: 26)
                    WeatherIconView(slug: slug, size: 22)
                    Text(label).font(.caption)
                }
            }
        }
        .padding()
    }
}
