import AstroCore
import SwiftData
import SwiftUI

/// Horizontal strip of all 12 signs (like AstroTalk / Co–Star's horoscope browser).
struct ZodiacStrip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Horoscopes for every sign")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases, id: \.self) { sign in
                        NavigationLink(value: sign) {
                            VStack(spacing: 6) {
                                Text(sign.symbol).font(.system(size: 24))
                                    .foregroundStyle(Theme.color(for: sign.element.rawValue))
                                Text(sign.name.uppercased()).font(Theme.mono(9)).foregroundStyle(Theme.text)
                            }
                            .frame(width: 78, height: 78)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }
}

/// Published daily horoscope for any sign, from free online horoscope feeds.
struct SignHoroscopeView: View {
    let sign: ZodiacSign

    @Environment(\.modelContext) private var context
    @State private var loader = ReadingLoader()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    Text(sign.symbol).font(.system(size: 54)).foregroundStyle(Theme.color(for: sign.element.rawValue))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sign.name).font(Theme.serif(32)).foregroundStyle(Theme.text)
                        Text(sign.dateRange.uppercased()).font(Theme.mono(11)).foregroundStyle(Theme.secondary)
                    }
                }
                HStack(spacing: 8) {
                    tag(sign.element.rawValue)
                    tag(sign.modality.rawValue)
                    tag("Ruler: \(sign.ruler.rawValue)")
                    tag(sign.rashiName)
                }
                Card {
                    SectionLabel("Today · \(Date.now.formatted(.dateTime.month(.wide).day()))")
                    ReadingBlock(loader: loader) { load(force: true) }
                }
            }
            .padding(20)
        }
        .astraScreen()
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { load(force: true) }
        .onAppear { load() }
    }

    private func tag(_ s: String) -> some View {
        Text(s.uppercased()).font(Theme.mono(9)).foregroundStyle(Theme.text)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.6))
    }

    private func load(force: Bool = false) {
        let sign = sign
        loader.loadText(key: "sign-\(sign.rawValue)-\(ReadingPeriod.today.bucket())", context: context, force: force) {
            try await HoroscopeFeed.daily(for: sign)
        }
    }
}
