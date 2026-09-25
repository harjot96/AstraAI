import AstroCore
import SwiftData
import SwiftUI

/// Tapping a placement opens a short AI explanation of that planet in the user's chart.
struct PlanetDetailSheet: View {
    let profile: BirthProfile
    let planet: Planet

    @Environment(\.modelContext) private var context
    @State private var loader = ReadingLoader()

    var body: some View {
        let body = profile.natalChart.body(planet)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(planet.symbol).font(.system(size: 40))
                    VStack(alignment: .leading) {
                        Text("\(planet.rawValue) in \(body.sign.name)").font(Theme.serif(26))
                        Text([body.house.map { "HOUSE \($0)" }, formatDegreeInSign(body.position.longitude),
                              body.position.isRetrograde ? "RETROGRADE" : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(Theme.mono(11)).foregroundStyle(Theme.secondary)
                    }
                }
                .foregroundStyle(Theme.text)
                Text(planet.keywords.uppercased()).font(Theme.mono(10)).tracking(1.2).foregroundStyle(Theme.gold)
                Hairline()
                ReadingBlock(loader: loader) { load(force: true) }
            }
            .padding(24)
        }
        .background(StarfieldBackground())
        .onAppear { load() }
    }

    private func load(force: Bool = false) {
        let p = profile
        loader.load(key: "planet-\(profile.id)-\(planet.rawValue)",
                    system: { AstrologerExpert.astra.systemPrompt(for: p) },
                    prompt: "Explain my \(planet.rawValue) placement (sign, house, and its closest aspects) in about 170 words, then one practical tip.",
                    context: context, force: force, maxTokens: 700)
    }
}
