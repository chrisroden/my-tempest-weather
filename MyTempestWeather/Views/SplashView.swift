import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            // Background gradient matching the app icon
            LinearGradient(
                colors: [Color(red: 0.129, green: 0.612, blue: 0.953),
                         Color(red: 0.039, green: 0.420, blue: 0.722)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "cloud.sun.fill")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.white)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                VStack(spacing: 4) {
                    Text("My Tempest")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Weather")
                        .font(.system(size: 22, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(iconOpacity)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding(.top, 12)
                    .opacity(iconOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
