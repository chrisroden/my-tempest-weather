import SwiftUI

struct WindView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Wind")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            CompassRose(degrees: Double(viewModel.windDirection))
                .frame(width: 120, height: 120)

            HStack(spacing: 24) {
                LabeledValue(label: "Speed",
                             value: "\(Int(viewModel.windSpeed.rounded())) \(viewModel.windUnitSymbol)")
                LabeledValue(label: "Gust",
                             value: "\(Int(viewModel.windGust.rounded())) \(viewModel.windUnitSymbol)")
                LabeledValue(label: "From",
                             value: viewModel.windDirectionCardinal)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Compass Rose

private struct CompassRose: View {
    let degrees: Double

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1.5)

            // Cardinal labels
            ForEach(Array(zip(["N","E","S","W"], [0.0,90,180,270])), id: \.0) { label, angle in
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .offset(y: -50)
                    .rotationEffect(.degrees(angle))
                    .rotationEffect(.degrees(-angle)) // keep text upright
            }

            // Arrow pointing FROM where the wind comes
            ArrowShape()
                .fill(Color.accentColor)
                .frame(width: 16, height: 48)
                .rotationEffect(.degrees(degrees), anchor: .center)
        }
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        // Arrowhead at top, tail at bottom
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.2, y: rect.midY))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.2, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.2, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
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
    WindView()
        .environment(WeatherViewModel())
        .padding()
}
