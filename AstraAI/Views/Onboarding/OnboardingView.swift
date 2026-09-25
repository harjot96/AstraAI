import SwiftData
import SwiftUI

struct OnboardingView: View {
    @State private var step = 0

    var body: some View {
        ZStack {
            StarfieldBackground()
            if step == 0 {
                welcome.transition(.opacity)
            } else {
                NavigationStack {
                    ProfileForm(mode: .onboarding)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            OrbitMark()
                .frame(width: 180, height: 180)
            VStack(spacing: 12) {
                Text("AstraAI")
                    .font(Theme.serif(46))
                    .foregroundStyle(Theme.text)
                Text("Your personal astrologer.\nWestern charts, Vedic kundli, numerology\n— and answers, any time you ask.")
                    .font(Theme.serif(17))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                Button("Get started") { step = 1 }
                    .buttonStyle(PillButtonStyle())
                Text("Charts are calculated on-device. For reflection & entertainment.")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
}

/// Decorative orbit illustration used on the welcome screen.
struct OrbitMark: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Theme.text.opacity(0.18), lineWidth: 0.6)
                    .scaleEffect(1 - CGFloat(i) * 0.27)
            }
            Circle()
                .fill(RadialGradient(colors: [Theme.gold, Theme.gold.opacity(0.2)], center: .center,
                                     startRadius: 1, endRadius: 22))
                .frame(width: 36, height: 36)
            Circle().fill(Theme.text).frame(width: 7, height: 7)
                .offset(x: 90)
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle().fill(Theme.gold.opacity(0.8)).frame(width: 5, height: 5)
                .offset(x: -65)
                .rotationEffect(.degrees(spin ? -360 : 0))
        }
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}
