import AstroCore
import SwiftData
import SwiftUI

struct TarotView: View {
    let me: BirthProfile

    @Environment(ProStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tarot").font(Theme.serif(30)).foregroundStyle(Theme.text).padding(.top, 12)
                    Text("Cards are drawn at random, then read against your birth chart.")
                        .font(Theme.serif(15)).foregroundStyle(Theme.secondary)

                    NavigationLink(value: TarotSpread.daily) { dailyTeaser }

                    SectionLabel("Spreads")
                    ForEach(TarotSpread.allCases.filter { $0 != .daily }) { spread in
                        NavigationLink(value: spread) { spreadRow(spread) }
                    }
                }
                .padding(20)
            }
            .astraScreen()
            .navigationBarHidden(true)
            .navigationDestination(for: TarotSpread.self) { TarotReadingView(me: me, spread: $0) }
        }
    }

    private var dailyTeaser: some View {
        HStack(spacing: 16) {
            TarotCardView(drawn: TarotDeck.dailyCard(seed: me.id.uuidString), isFaceUp: false, width: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text("CARD OF THE DAY").font(Theme.mono(10)).tracking(1.4).foregroundStyle(Theme.gold)
                Text("Reveal today's card").font(Theme.serif(20)).foregroundStyle(Theme.text)
                Text("Free · new card every day").font(Theme.mono(10)).foregroundStyle(Theme.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.4), lineWidth: 0.6))
    }

    private func spreadRow(_ spread: TarotSpread) -> some View {
        HStack(spacing: 14) {
            Text("\(spread.positions.count)").font(Theme.serif(26)).foregroundStyle(Theme.gold).frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(spread.title).font(Theme.serif(17)).foregroundStyle(Theme.text)
                Text(spread.blurb).font(Theme.serif(13)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            if !store.isPro && spread.positions.count > 1 {
                Text("PRO").font(Theme.mono(9, weight: .bold)).foregroundStyle(Theme.gold)
            }
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TarotReadingView: View {
    let me: BirthProfile
    let spread: TarotSpread

    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @State private var question = ""
    @State private var cards: [DrawnCard] = []
    @State private var revealed: Set<Int> = []
    @State private var loader = ReadingLoader()

    private var allRevealed: Bool { !cards.isEmpty && revealed.count == cards.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(spread.title).font(Theme.serif(28)).foregroundStyle(Theme.text)
                Text(spread.blurb).font(Theme.serif(15)).foregroundStyle(Theme.secondary)

                if spread != .daily && cards.isEmpty {
                    TextField("Your question (optional)", text: $question, axis: .vertical)
                        .font(Theme.serif(16))
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    Button("Shuffle & draw", action: draw).buttonStyle(PillButtonStyle())
                }

                if !cards.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(cards) { drawn in
                            VStack(spacing: 8) {
                                TarotCardView(drawn: drawn, isFaceUp: revealed.contains(drawn.id),
                                              width: cards.count == 1 ? 170 : 104)
                                    .onTapGesture { reveal(drawn) }
                                Text(drawn.position.uppercased()).font(Theme.mono(9)).tracking(1)
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if !allRevealed {
                        Text("Tap each card to turn it over").font(Theme.mono(11)).foregroundStyle(Theme.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                if allRevealed {
                    Card {
                        ForEach(cards) { drawn in
                            Text("\(drawn.position.uppercased()) · \(drawn.card.name)\(drawn.isReversed ? " (reversed)" : "")")
                                .font(Theme.mono(10)).foregroundStyle(Theme.gold)
                        }
                        Hairline()
                        ReadingBlock(loader: loader) { interpret(force: true) }
                    }
                    if spread != .daily {
                        Button("New reading") { cards = []; revealed = []; loader = ReadingLoader() }
                            .buttonStyle(PillButtonStyle(filled: false))
                    }
                }
            }
            .padding(20)
        }
        .astraScreen()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if spread == .daily && cards.isEmpty { cards = [TarotDeck.dailyCard(seed: me.id.uuidString)] }
        }
    }

    private func draw() {
        guard store.require("Multi-card spreads are part of AstraAI Pro.") else { return }
        withAnimation { cards = TarotDeck.draw(spread) }
    }

    private func reveal(_ drawn: DrawnCard) {
        revealed.insert(drawn.id)
        if allRevealed { interpret() }
    }

    private func interpret(force: Bool = false) {
        let profile = me
        let spreadText = cards.map(\.description).joined(separator: "\n")
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        I drew the \(spread.title) spread\(q.isEmpty ? "" : " for the question: \"\(q)\"").
        Cards (already drawn — do not draw others):
        \(spreadText)
        Read each card in its position, then weave them into one message\(spread == .yesNo ? " and give a clear Yes, No or Not yet" : ""). \
        Relate the reading to one or two of my chart placements or current transits. 150–260 words.
        """
        let day = ReadingPeriod.today.bucket()
        let key = spread == .daily ? "tarot-daily-\(me.id)-\(day)"
            : "tarot-\(me.id)-\(spread.rawValue)-\(cards.map { "\($0.card.id)\($0.isReversed ? "r" : "")" }.joined(separator: ","))-\(q.hashValue)"
        loader.load(key: key, system: { AstrologerExpert.tarot.systemPrompt(for: profile) },
                    prompt: prompt, context: context, force: force, maxTokens: 900)
    }
}
