import AstroCore
import SwiftUI

/// A tarot card that flips from its back to its face; reversed cards render upside down.
struct TarotCardView: View {
    let drawn: DrawnCard
    var isFaceUp: Bool
    var width: CGFloat = 104

    var body: some View {
        ZStack {
            back.opacity(isFaceUp ? 0 : 1)
                .accessibilityHidden(true)
            // The face only exists once revealed, so its name can't leak (e.g. to VoiceOver) early.
            if isFaceUp {
                face
                    .accessibilityHidden(true)
                    .rotationEffect(.degrees(drawn.isReversed ? 180 : 0))
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: width * 1.65)
        .rotation3DEffect(.degrees(isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFaceUp)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFaceUp ? "\(drawn.card.name)\(drawn.isReversed ? ", reversed" : "")" : "Face-down card")
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: width * 0.09, style: .continuous) }

    private var back: some View {
        shape.fill(LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.22), Theme.background],
                                  startPoint: .top, endPoint: .bottom))
            .overlay(shape.inset(by: 5).stroke(Theme.gold.opacity(0.6), lineWidth: 0.8))
            .overlay {
                ZStack {
                    Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 0.6).frame(width: width * 0.5)
                    Image(systemName: "sparkle").font(.system(size: width * 0.18)).foregroundStyle(Theme.gold)
                }
            }
    }

    private var face: some View {
        let accent = drawn.card.suit.map { Theme.color(for: $0.element.rawValue) } ?? Theme.gold
        return shape.fill(Color(red: 0.96, green: 0.94, blue: 0.89))
            .overlay(shape.inset(by: 4).stroke(accent, lineWidth: 1))
            .overlay {
                VStack(spacing: width * 0.05) {
                    Text(drawn.card.label).font(Theme.serif(width * 0.13, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(drawn.card.suit?.symbol ?? "☉")
                        .font(.system(size: width * 0.34))
                        .foregroundStyle(accent)
                    Spacer(minLength: 0)
                    Text(drawn.card.name.uppercased())
                        .font(Theme.mono(width * 0.065, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(Theme.background)
                .padding(width * 0.1)
            }
    }
}
