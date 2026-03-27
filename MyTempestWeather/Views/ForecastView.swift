import SwiftUI

struct ForecastView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("7-Day Forecast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.dailyForecasts) { day in
                        DayCard(day: day, viewModel: viewModel)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Day Card

private struct DayCard: View {
    let day: DailyForecast
    let viewModel: WeatherViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text(day.weekdayLabel)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Image(systemName: day.icon.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .foregroundStyle(day.icon.iconTint)
                .frame(height: 32)

            Text(high)
                .font(.subheadline.bold())

            Text(low)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let pop = day.precipProbability, pop > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(pop)%")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .frame(width: 64)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var high: String {
        "\(Int((day.airTempHigh).rounded()))\(viewModel.tempUnitSymbol)"
    }
    private var low: String {
        "\(Int((day.airTempLow).rounded()))\(viewModel.tempUnitSymbol)"
    }
}

#Preview {
    ForecastView()
        .environment(WeatherViewModel())
        .padding()
}
