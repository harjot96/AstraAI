import AstroCore
import SwiftData
import SwiftUI

struct ChartScreen: View {
    let me: BirthProfile

    enum Tradition: String, CaseIterable { case western = "Western", vedic = "Vedic Kundli" }

    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @State private var tradition: Tradition = .western
    @State private var selected: Planet?
    @State private var loader = ReadingLoader()

    var body: some View {
        let natal = me.natalChart
        let vedic = VedicChart(natal: natal)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("Tradition", selection: $tradition) {
                        ForEach(Tradition.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)

                    if tradition == .western {
                        WesternChartSection(chart: natal, selected: $selected)
                    } else {
                        VedicChartSection(chart: vedic)
                    }

                    Card {
                        SectionLabel(tradition == .western ? "Your chart, interpreted" : "Your kundli, interpreted")
                        if loader.text.isEmpty && !loader.isLoading && loader.errorMessage == nil {
                            Button("Read my \(tradition == .western ? "chart" : "kundli")\(store.isPro ? "" : " ✦ Pro")") {
                                if store.require("Full chart and kundli readings are part of AstraAI Pro.") { interpret() }
                            }
                                .buttonStyle(PillButtonStyle(filled: false))
                        } else {
                            ReadingBlock(loader: loader) { interpret(force: true) }
                        }
                    }
                }
                .padding(20)
            }
            .astraScreen()
            .navigationTitle(me.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { planet in
                PlanetDetailSheet(profile: me, planet: planet)
                    .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: tradition) { interpret(onlyIfCached: true) }
        .onAppear { interpret(onlyIfCached: true) }
    }

    private func interpret(force: Bool = false, onlyIfCached: Bool = false) {
        let key = "chart-\(me.id)-\(tradition.rawValue)"
        if onlyIfCached {
            let has = (try? context.fetch(FetchDescriptor<CachedReading>(predicate: #Predicate { $0.key == key })).first) != nil
            guard has else { loader.text = ""; loader.errorMessage = nil; return }
        }
        let profile = me
        let prompt = tradition == .western
            ? "Give me a full natal chart reading (400–500 words): core identity (Sun, Moon, Rising), mind and communication, love style, drive, career direction (Midheaven, 10th house), life lessons (Saturn, nodes), and the three most important aspects. End with 3 short bullet-point strengths and 2 growth edges."
            : "Give me a Vedic kundli reading (400–500 words): lagna and its lord, Moon rashi and janma nakshatra, key bhava placements, notable yogas you can see, the current mahadasha/antardasha and what it activates, Mangal dosha status, and 2–3 simple classical remedies."
        loader.load(key: key, system: { AstrologerExpert.astra.systemPrompt(for: profile) },
                    prompt: prompt, context: context, force: force, maxTokens: 1800)
    }
}

extension Planet: Identifiable { public var id: String { rawValue } }

private struct WesternChartSection: View {
    let chart: NatalChart
    @Binding var selected: Planet?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ChartWheel(chart: chart).padding(.horizontal, 4)
            Text(chart.bigThree).font(Theme.mono(12)).foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity)

            Card {
                SectionLabel("Placements")
                ForEach(chart.bodies) { body in
                    Button { selected = body.planet } label: {
                        HStack {
                            Text(body.planet.symbol).font(.system(size: 18)).frame(width: 28)
                            Text(body.planet.rawValue).font(Theme.serif(16))
                            Spacer()
                            Text("\(body.sign.symbol) \(body.sign.name) \(formatDegreeInSign(body.position.longitude))")
                                .font(Theme.mono(12))
                            if let h = body.house { Text("H\(h)").font(Theme.mono(11)).foregroundStyle(Theme.secondary).frame(width: 30) }
                            if body.position.isRetrograde { Text("℞").foregroundStyle(Theme.tense) }
                        }
                        .foregroundStyle(Theme.text)
                    }
                    if body.planet != chart.bodies.last?.planet { Hairline() }
                }
            }

            ElementBalanceCard(balance: chart.balance)

            Card {
                SectionLabel("Aspects")
                ForEach(Array(chart.aspects.prefix(14).enumerated()), id: \.offset) { _, a in
                    HStack {
                        Text("\(a.first.symbol) \(a.type.symbol) \(a.second.symbol)").frame(width: 70, alignment: .leading)
                            .foregroundStyle(a.type.harmony > 0 ? Theme.flowing : a.type.harmony < 0 ? Theme.tense : Theme.gold)
                        Text("\(a.first.rawValue) \(a.type.rawValue.lowercased()) \(a.second.rawValue)").font(Theme.serif(14))
                        Spacer()
                        Text(String(format: "%.1f°", a.orb)).font(Theme.mono(10)).foregroundStyle(Theme.secondary)
                    }
                    .foregroundStyle(Theme.text)
                }
            }
            if chart.houses == nil {
                Text("Birth time unknown — houses and rising sign are hidden. Add your time in You → Edit.")
                    .font(Theme.mono(11)).foregroundStyle(Theme.secondary)
            }
        }
    }
}

private struct ElementBalanceCard: View {
    let balance: ElementBalance

    var body: some View {
        let total = max(1, balance.elements.values.reduce(0, +))
        Card {
            SectionLabel("Elements · dominant \(balance.dominantElement.rawValue), \(balance.dominantModality.rawValue)")
            ForEach(Element.allCases, id: \.self) { el in
                let n = balance.elements[el] ?? 0
                HStack {
                    Text(el.rawValue.uppercased()).font(Theme.mono(10)).frame(width: 52, alignment: .leading)
                        .foregroundStyle(Theme.secondary)
                    GeometryReader { g in
                        Capsule().fill(Theme.hairline)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.color(for: el.rawValue))
                                    .frame(width: g.size.width * CGFloat(n) / CGFloat(total))
                            }
                    }
                    .frame(height: 6)
                    Text("\(n)").font(Theme.mono(10)).foregroundStyle(Theme.secondary).frame(width: 20)
                }
            }
        }
    }
}

private struct VedicChartSection: View {
    let chart: VedicChart

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SouthIndianChart(chart: chart)
            HStack(spacing: 10) {
                stat("Lagna", chart.lagnaSign?.rashiName ?? "—")
                stat("Rashi", chart.moonSign.rashiName)
                stat("Nakshatra", chart.janmaNakshatra.name)
            }
            HStack(spacing: 10) {
                stat("Mangal dosha", chart.isManglik ? "Present" : "Absent")
                stat("Gemstone", chart.suggestedGemstone.stone)
            }

            Card {
                SectionLabel("Grahas")
                ForEach(chart.placements) { p in
                    HStack {
                        Text(p.planet.vedicName).font(Theme.serif(16)).frame(width: 80, alignment: .leading)
                        Text("\(p.rashi.rashiName) \(formatDegreeInSign(p.siderealLongitude))").font(Theme.mono(11))
                        Spacer()
                        Text("\(p.nakshatra.name) \(p.pada)").font(Theme.mono(10)).foregroundStyle(Theme.secondary)
                        if let h = p.house { Text("B\(h)").font(Theme.mono(10)).foregroundStyle(Theme.gold).frame(width: 28) }
                    }
                    .foregroundStyle(Theme.text)
                }
            }

            DashaTimeline(chart: chart)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Theme.mono(9)).tracking(1).foregroundStyle(Theme.secondary)
            Text(value).font(Theme.serif(16)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DashaTimeline: View {
    let chart: VedicChart

    var body: some View {
        let current = chart.currentDasha()
        Card {
            SectionLabel("Vimshottari dasha")
            if let current {
                Text("Now: \(current.maha.lord.vedicName) – \(current.antar.lord.vedicName)")
                    .font(Theme.serif(20)).foregroundStyle(Theme.text)
                Text("Antardasha until \(current.antar.end.formatted(.dateTime.month(.abbreviated).year()))")
                    .font(Theme.mono(11)).foregroundStyle(Theme.gold)
                Hairline()
            }
            ForEach(chart.dashas) { d in
                let isNow = d.contains(.now)
                HStack {
                    Circle().fill(isNow ? Theme.gold : Theme.hairline).frame(width: 7, height: 7)
                    Text(d.lord.vedicName).font(Theme.serif(15)).foregroundStyle(isNow ? Theme.text : Theme.secondary)
                    Spacer()
                    Text("\(d.start.formatted(.dateTime.year())) – \(d.end.formatted(.dateTime.year()))")
                        .font(Theme.mono(11)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}
