import SwiftUI

/// Animated splash shown right after the static launch screen. It starts with the
/// launch logo at the same size and position (200pt, centred), so the handoff is seamless.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    @State private var glow = false
    @State private var showWordmark = false

    var body: some View {
        ZStack {
            StarfieldBackground()
            Image("LaunchLogo")
                .resizable()
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(spin ? 12 : 0))
                .scaleEffect(glow ? 1.08 : 1)
                .shadow(color: Theme.gold.opacity(glow ? 0.45 : 0), radius: 30)
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text("AstraAI")
                    .font(Theme.serif(40))
                    .foregroundStyle(Theme.text)
                Text("YOUR PERSONAL ASTROLOGER")
                    .font(Theme.mono(11))
                    .tracking(2.5)
                    .foregroundStyle(Theme.gold)
            }
            .offset(y: 170)
            .opacity(showWordmark ? 1 : 0)
            .offset(y: showWordmark ? 0 : 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AstraAI, your personal astrologer")
        .onAppear {
            if reduceMotion {
                showWordmark = true
                return
            }
            withAnimation(.easeInOut(duration: 1.6)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9).delay(0.1)) { glow = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) { showWordmark = true }
        }
    }
}
