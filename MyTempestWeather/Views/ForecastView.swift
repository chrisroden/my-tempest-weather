import SwiftUI

struct ForecastView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @State private var expandedDayIds: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("7-Day Forecast")
                .font(.headline)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.dailyForecasts.enumerated()), id: \.element.id) { index, day in
                    let isExpanded = expandedDayIds.contains(day.id)
                    let isLast = index == viewModel.dailyForecasts.count - 1

                    VStack(spacing: 0) {
                        DayRow(
                            day: day,
                            viewModel: viewModel,
                            isExpanded: isExpanded
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if isExpanded {
                                    expandedDayIds.remove(day.id)
                                } else {
                                    expandedDayIds.insert(day.id)
                                }
                            }
                        }

                        if isExpanded {
                            let hours = viewModel.hourlyForecasts(for: day)
                            if !hours.isEmpty {
                                HourlyStrip(hours: hours, viewModel: viewModel)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }

                        if !isLast {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let day: DailyForecast
    let viewModel: WeatherViewModel
    let isExpanded: Bool
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 12) {
            Text(day.weekdayLabel)
                .font(.subheadline.bold())
                .foregroundStyle(isExpanded ? Color.accentColor : .primary)
                .frame(width: 42, alignment: .leading)

            WeatherIconView(slug: day.icon, size: 24)
                .frame(width: 28)

            if sizeClass == .regular {
                Text(day.conditions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(day.precipProbability > 0 ? Color.blue : Color.secondary)
                Text("\(day.precipProbability)%")
                    .font(.caption)
                    .foregroundStyle(day.precipProbability > 0 ? Color.blue : Color.secondary)
            }
            .fixedSize()

            HStack(spacing: 4) {
                if lowFirst {
                    Text(low)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(high)
                        .font(.subheadline.bold())
                } else {
                    Text(high)
                        .font(.subheadline.bold())
                    Text(low)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var high: String {
        "\(Int(day.airTempHigh.rounded()))\(viewModel.tempUnitSymbol)"
    }
    private var low: String {
        "\(Int(day.airTempLow.rounded()))\(viewModel.tempUnitSymbol)"
    }
    private var lowFirst: Bool { viewModel.lowBeforeHigh(for: day) }
}

// MARK: - Hourly Strip

private struct HourlyStrip: View {
    let hours: [HourlyForecast]
    let viewModel: WeatherViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(hours) { hour in
                    HourCard(hour: hour, viewModel: viewModel)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, 6)
    }
}

// MARK: - Hour Card

private struct HourCard: View {
    let hour: HourlyForecast
    let viewModel: WeatherViewModel

    var body: some View {
        VStack(spacing: 5) {
            Text(hourLabel)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            WeatherIconView(slug: hour.icon, size: 20)
                .frame(height: 24)

            Text(temp)
                .font(.caption.bold())

            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(hour.precipProbability > 0 ? Color.blue : Color.secondary)
                Text("\(Int(hour.precipProbability))%")
                    .font(.caption2)
                    .foregroundStyle(hour.precipProbability > 0 ? Color.blue : Color.secondary)
            }
        }
        .frame(width: 52)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var hourLabel: String {
        let date = Date(timeIntervalSince1970: TimeInterval(hour.time))
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    private var temp: String {
        "\(Int(hour.airTemperature.rounded()))\(viewModel.tempUnitSymbol)"
    }
}

#Preview {
    ForecastView()
        .environment(WeatherViewModel())
        .padding()
}
