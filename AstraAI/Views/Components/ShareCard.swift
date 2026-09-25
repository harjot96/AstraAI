import AstroCore
import SwiftUI

/// Story-sized image card users can post (big three + today's headline).
struct ShareCardView: View {
    let name: String
    let bigThree: String
    let headline: String
    let date: Date

    var body: some View {
        ZStack {
            StarfieldBackground()
            VStack(alignment: .leading, spacing: 18) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(Theme.mono(13)).tracking(2).foregroundStyle(Theme.secondary)
                Spacer()
                OrbitMark().frame(width: 150, height: 150)
                Text(headline)
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(bigThree).font(Theme.mono(14)).foregroundStyle(Theme.gold)
                Spacer()
                HStack {
                    Text(name.uppercased()).font(Theme.mono(12)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Text("✦ ASTRAAI").font(Theme.mono(12, weight: .semibold)).foregroundStyle(Theme.text)
                }
            }
            .padding(36)
        }
        .frame(width: 390, height: 693)
    }

    /// Renders the card to an image for ShareLink.
    @MainActor
    static func render(name: String, bigThree: String, headline: String) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(name: name, bigThree: bigThree,
                                                            headline: headline, date: .now))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }

    /// First bold line of a reading (the "theme"), falling back to the first sentence.
    static func headline(from reading: String) -> String {
        if let start = reading.range(of: "**"),
           let end = reading.range(of: "**", range: start.upperBound..<reading.endIndex) {
            let s = String(reading[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { return s }
        }
        let first = reading.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? ""
        return first.isEmpty ? "The stars are speaking." : first
    }
}

/// Share button that renders the card lazily when tapped.
struct ShareReadingButton: View {
    let profile: BirthProfile
    let reading: String

    var body: some View {
        if let image = ShareCardView.render(name: profile.name, bigThree: profile.natalChart.bigThree,
                                            headline: ShareCardView.headline(from: reading)) {
            ShareLink(item: image, preview: SharePreview("My AstraAI reading", image: image)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
        }
    }
}
