import AstroCore
import SwiftData
import SwiftUI

struct TodayView: View {
    let me: BirthProfile

    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @State private var period: ReadingPeriod = .today
    @State private var loader = ReadingLoader()
    @State private var showingYou = false
    @AppStorage(DailyNotifier.enabledKey) private var remindersOn = false
    @AppStorage("astra.reminderPromptDismissed") private var reminderPromptDismissed = false

    private var transits: TransitReport { TransitReport(natal: me.natalChart) }
    private var panchang: Panchang { Panchang(date: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    periodPicker
                    Card {
                        HStack {
                            SectionLabel("\(period.rawValue == "Today" ? "Today's" : "This \(period.rawValue.lowercased())'s") horoscope")
                            if !loader.isLoading && !loader.text.isEmpty {
                                ShareReadingButton(profile: me, reading: loader.text)
                            }
                        }
                        ReadingBlock(loader: loader) { load(force: true) }
                    }
                    if !remindersOn && !reminderPromptDismissed { reminderCard }
                    ZodiacStrip()
                    moonCard
                    panchangCard
                    transitsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .astraScreen()
            .navigationBarHidden(true)
            .navigationDestination(for: ZodiacSign.self) { SignHoroscopeView(sign: $0) }
            .refreshable { load(force: true) }
            .sheet(isPresented: $showingYou) { YouView(me: me) }
        }
        .onAppear { load() }
        .onChange(of: period) { load() }
    }

    private var reminderCard: some View {
        Card {
            SectionLabel("Daily horoscope")
            Text("Get a note from the sky every morning at \(DailyNotifier.hour) AM.")
                .font(Theme.serif(16)).foregroundStyle(Theme.text)
            HStack(spacing: 12) {
                Button("Turn on") { Task { remindersOn = await DailyNotifier.enable(for: me) ; reminderPromptDismissed = true } }
                    .buttonStyle(PillButtonStyle())
                Button("Not now") { reminderPromptDismissed = true }
                    .buttonStyle(PillButtonStyle(filled: false))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(Theme.mono(11)).tracking(1.5).foregroundStyle(Theme.secondary)
                Spacer()
                if ProStore.paywallEnabled && store.isPro {
                    Text("PRO").font(Theme.mono(10, weight: .bold)).foregroundStyle(Theme.gold)
                }
                Button { showingYou = true } label: {
                    Image(systemName: "person.crop.circle").font(.system(size: 24)).foregroundStyle(Theme.text)
                }
                .accessibilityLabel("Profile and settings")
            }
            Text("Good \(greetingWord), \(me.name.components(separatedBy: " ").first ?? me.name).")
                .font(Theme.serif(32))
                .foregroundStyle(Theme.text)
            Text(me.natalChart.bigThree)
                .font(Theme.mono(12)).foregroundStyle(Theme.gold)
        }
        .padding(.top, 16)
    }

    private var greetingWord: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        default: "evening"
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(ReadingPeriod.allCases) { p in
                Button {
                    if p == .today || store.require("Weekly, monthly and yearly forecasts are part of AstraAI Pro.") {
                        period = p
                    }
                } label: {
                    Text(p == .today || store.isPro ? p.rawValue.uppercased() : "\(p.rawValue.uppercased()) ✦")
                        .font(Theme.mono(11, weight: .medium)).tracking(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(period == p ? Theme.background : Theme.secondary)
                        .background(period == p ? Theme.text : .clear, in: Capsule())
                }
            }
        }
        .padding(3)
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))
    }

    private var moonCard: some View {
        let moon = transits.moonPhase
        return Card {
            SectionLabel("Moon")
            HStack(spacing: 16) {
                Text(moon.emoji).font(.system(size: 44))
                VStack(alignment: .leading, spacing: 4) {
                    Text(moon.name).font(Theme.serif(20)).foregroundStyle(Theme.text)
                    Text("in \(transits.sign(of: .moon).name) · \(Int(moon.illumination * 100))% illuminated")
                        .font(Theme.mono(11)).foregroundStyle(Theme.secondary)
                    Text(moon.guidance).font(Theme.serif(14)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    private var panchangCard: some View {
        let p = panchang
        return Card {
            HStack {
                SectionLabel("Panchang")
                if p.isInauspicious {
                    Text("AVOID NEW STARTS").font(Theme.mono(9, weight: .semibold)).foregroundStyle(Theme.tense)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                row("Tithi", "\(p.paksha) \(p.tithiName)")
                row("Nakshatra", p.nakshatra.name)
                row("Yoga", p.yogaName)
                row("Karana", p.karanaName)
                row("Vara", "\(p.varaName) · \(p.varaLord.vedicName)")
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k.uppercased()).font(Theme.mono(10)).foregroundStyle(Theme.secondary)
            Text(v).font(Theme.serif(16)).foregroundStyle(Theme.text)
        }
    }

    private var transitsCard: some View {
        let t = transits
        return Card {
            SectionLabel("Active transits")
            if t.toNatal.isEmpty {
                Text("A quiet sky for you today.").font(Theme.serif(15)).foregroundStyle(Theme.secondary)
            }
            ForEach(Array(t.toNatal.prefix(6).enumerated()), id: \.offset) { _, a in
                HStack {
                    Text("\(a.first.symbol) \(a.type.symbol) \(a.second.symbol)")
                        .font(.system(size: 17)).frame(width: 70, alignment: .leading)
                        .foregroundStyle(a.type.harmony > 0 ? Theme.flowing : a.type.harmony < 0 ? Theme.tense : Theme.gold)
                    Text("\(a.first.rawValue) \(a.type.rawValue.lowercased()) your \(a.second.rawValue)")
                        .font(Theme.serif(15)).foregroundStyle(Theme.text)
                    Spacer()
                }
            }
            if !t.retrogrades.isEmpty {
                Hairline()
                Text("RETROGRADE: " + t.retrogrades.map(\.rawValue).joined(separator: ", ").uppercased())
                    .font(Theme.mono(10)).foregroundStyle(Theme.tense)
            }
        }
    }

    private func load(force: Bool = false) {
        let profile = me
        let sunSign = me.natalChart.sunSign
        var fallback: (@MainActor () async throws -> String)?
        if period == .today {
            fallback = { @MainActor in try await TodayView.publishedHoroscope(for: sunSign) }
        }
        loader.load(key: "horoscope-\(me.id)-\(period.rawValue)-\(period.bucket())",
                    system: { AstrologerPrompts.persona + "\n\n=== USER DATA ===\n" + AstrologerPrompts.context(for: profile) },
                    prompt: AstrologerPrompts.horoscopePrompt(period: period, profile: me),
                    context: context, force: force, fallback: fallback)
    }

    /// Free published sun-sign horoscope, shown if every AI provider is unavailable.
    private static func publishedHoroscope(for sign: ZodiacSign) async throws -> String {
        let text = try await HoroscopeFeed.daily(for: sign)
        return "**\(sign.symbol) \(sign.name) today**\n\n\(text)"
    }
}
