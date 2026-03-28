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
                .fill(viewModel.isWebSocketConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(viewModel.isWebSocketConnected ? "Live" : "Polling")
                    .font(.caption.bold())
                    .foregroundStyle(viewModel.isWebSocketConnected ? .green : .orange)
                if let updated = viewModel.lastUpdated {
                    Text(updated, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    HeaderBannerView()
        .environment(WeatherViewModel())
        .padding()
}
