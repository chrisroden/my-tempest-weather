import SwiftUI

struct CurrentConditionsView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 12) {
            WeatherIconView(slug: viewModel.weatherIcon, size: 64)

            Text(temperatureString(viewModel.currentTemperature))
                .font(.system(size: 56, weight: .thin, design: .rounded))
                .minimumScaleFactor(0.5)

            Text(viewModel.weatherCondition)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 24) {
                LabeledValue(label: "Feels", value: temperatureString(viewModel.feelsLike))
                if viewModel.todayLowBeforeHigh {
                    LabeledValue(label: "Low",  value: temperatureString(viewModel.todayLow))
                    LabeledValue(label: "High", value: temperatureString(viewModel.todayHigh))
                } else {
                    LabeledValue(label: "High", value: temperatureString(viewModel.todayHigh))
                    LabeledValue(label: "Low",  value: temperatureString(viewModel.todayLow))
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func temperatureString(_ value: Double) -> String {
        "\(Int(value.rounded()))\(viewModel.tempUnitSymbol)"
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    CurrentConditionsView()
        .environment(WeatherViewModel())
        .padding()
}
