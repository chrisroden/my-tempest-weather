import SwiftUI

/// Top banner matching the Pi console layout:
/// left = location + live clock, centre = condition, right = connection status.
struct HeaderBannerView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(alignment: .center, spacing: 8) {
                locationClockStack
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(viewModel.weatherCondition)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                connectionStack
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Sub-views

    private var locationClockStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.locationName)
                .font(.subheadline.bold())
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(Date.now, format: .dateTime.weekday(.abbreviated))
                    .foregroundStyle(Color.accentColor)
                Text(Date.now, format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.secondary)
                Text(Date.now, format: .dateTime.hour().minute().second())
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private var connectionStack: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                if let updated = viewModel.lastUpdated {
                    Text(updated, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// "Live"/"Polling" for the Tempest station; "Forecast" for WeatherKit locations.
    private var statusText: String {
        guard viewModel.isStationSelected else { return "Forecast" }
        return viewModel.isWebSocketConnected ? "Live" : "Polling"
    }

    private var statusColor: Color {
        guard viewModel.isStationSelected else { return .secondary }
        return viewModel.isWebSocketConnected ? .green : .orange
    }
}

#Preview {
    HeaderBannerView()
        .environment(WeatherViewModel())
        .padding()
}
