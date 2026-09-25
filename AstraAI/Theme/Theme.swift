import SwiftUI

/// Editorial, monochrome-cosmic look (inspired by Co–Star's serif + mono type
/// pairing), rendered on a deep night-sky background with a single gold accent.
enum Theme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.055)
    static let surface = Color.white.opacity(0.045)
    static let hairline = Color.white.opacity(0.12)
    static let text = Color(red: 0.95, green: 0.94, blue: 0.91)
    static let secondary = Color(red: 0.95, green: 0.94, blue: 0.91).opacity(0.58)
    static let gold = Color(red: 0.85, green: 0.75, blue: 0.54)
    static let flowing = Color(red: 0.55, green: 0.78, blue: 0.70)
    static let tense = Color(red: 0.90, green: 0.52, blue: 0.47)

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func color(for element: String) -> Color {
        switch element {
        case "Fire": Color(red: 0.93, green: 0.55, blue: 0.40)
        case "Earth": Color(red: 0.62, green: 0.74, blue: 0.47)
        case "Air": Color(red: 0.62, green: 0.74, blue: 0.93)
        default: Color(red: 0.55, green: 0.62, blue: 0.93)
        }
    }
}

/// Small uppercase monospaced label, e.g. "YOUR BIG THREE".
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(11, weight: .medium))
            .tracking(1.6)
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
}

/// Primary capsule button in the editorial style.
struct PillButtonStyle: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(13, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .foregroundStyle(filled ? Theme.background : Theme.text)
            .background(filled ? Theme.text : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(Theme.text.opacity(filled ? 0 : 0.5), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Deterministic starfield drawn with Canvas.
struct StarfieldBackground: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededGenerator(seed: 42)
            for _ in 0..<140 {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let r = Double.random(in: 0.3...1.3, using: &rng)
                let a = Double.random(in: 0.15...0.7, using: &rng)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(a)))
            }
        }
        .background(
            RadialGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.22).opacity(0.7), Theme.background],
                           center: .top, startRadius: 10, endRadius: 520)
        )
        .background(Theme.background)
        .ignoresSafeArea()
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

extension View {
    /// Standard screen chrome: starfield + scroll content inset.
    func astraScreen() -> some View {
        self.background(StarfieldBackground())
            .scrollContentBackground(.hidden)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
