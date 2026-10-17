import SwiftUI
import WeatherKit

/// The Apple Weather mark and legal link that WeatherKit requires wherever its data is shown.
struct WeatherAttributionView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var attribution: WeatherAttribution?
    @State private var failed = false

    var body: some View {
        VStack(spacing: 6) {
            if let attribution {
                AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(" Weather").font(.caption.bold())
                }
                .frame(height: 14)
                Link("Other data sources", destination: attribution.legalPageURL)
                    .font(.caption2)
            } else if failed {
                // Fallback text so the attribution is never missing.
                Text("Weather data provided by Apple Weather")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            do {
                attribution = try await viewModel.weatherAttribution()
            } catch {
                failed = true
            }
        }
    }
}

#Preview {
    WeatherAttributionView()
        .environment(WeatherViewModel())
}
