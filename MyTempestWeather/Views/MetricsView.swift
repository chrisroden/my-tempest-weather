import SwiftUI

struct MetricsView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conditions")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                MetricTile(
                    symbol: "humidity.fill",
                    tint: .cyan,
                    label: "Humidity",
                    value: "\(viewModel.relativeHumidity)%"
                )
                MetricTile(
                    symbol: pressureTrendSymbol,
                    tint: .indigo,
                    label: "Pressure",
                    value: "\(String(format: "%.1f", viewModel.seaLevelPressure)) \(viewModel.pressureUnitSymbol)"
                )
                MetricTile(
                    symbol: "sun.max.fill",
                    tint: uvTint,
                    label: "UV Index",
                    value: String(format: "%.1f", viewModel.uvIndex)
                )
                MetricTile(
                    symbol: "drop.fill",
                    tint: .blue,
                    label: "Precip 24h",
                    value: "\(String(format: "%.2f", viewModel.precipAccumLocalDay)) \(viewModel.precipUnitSymbol)"
                )
                // Lightning counts come from the station's sensor; WeatherKit has no equivalent.
                if viewModel.isStationSelected {
                    MetricTile(
                        symbol: "bolt.fill",
                        tint: .yellow,
                        label: "Lightning 1h",
                        value: "\(viewModel.lightningLast1hr)"
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pressureTrendSymbol: String {
        switch viewModel.pressureTrend.lowercased() {
        case "rising", "rising rapidly": return "arrow.up"
        case "falling", "falling rapidly": return "arrow.down"
        default: return "arrow.left.and.right"
        }
    }

    private var uvTint: Color {
        let uv = viewModel.uvIndex
        if uv < 3  { return .green }
        if uv < 6  { return .yellow }
        if uv < 8  { return .orange }
        if uv < 11 { return .red }
        return .purple
    }
}

// MARK: - Tile

private struct MetricTile: View {
    let symbol: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    MetricsView()
        .environment(WeatherViewModel())
        .padding()
}
