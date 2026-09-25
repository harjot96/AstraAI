import AstroCore
import SwiftData
import SwiftUI

struct MatchView: View {
    let me: BirthProfile

    @Query(filter: #Predicate<BirthProfile> { !$0.isPrimary }, sort: \.createdAt) private var others: [BirthProfile]
    @State private var adding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Compatibility").font(Theme.serif(30)).foregroundStyle(Theme.text).padding(.top, 12)
                    Text("Western synastry + Vedic Kundli Milan (36 Guna) for partners, crushes, friends and family.")
                        .font(Theme.serif(15)).foregroundStyle(Theme.secondary)
                    ForEach(others) { p in
                        NavigationLink(value: p) { personRow(p) }
                    }
                    Button { adding = true } label: {
                        Label("Add a person", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle(filled: others.isEmpty))
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .astraScreen()
            .navigationBarHidden(true)
            .navigationDestination(for: BirthProfile.self) { MatchDetailView(me: me, other: $0) }
            .sheet(isPresented: $adding) { NavigationStack { ProfileForm(mode: .add) } }
        }
    }

    private func personRow(_ p: BirthProfile) -> some View {
        let syn = Synastry(me.natalChart, p.natalChart)
        let guna = GunaMilan(first: VedicChart(natal: me.natalChart), second: VedicChart(natal: p.natalChart))
        return HStack(spacing: 14) {
            Text(p.natalChart.sunSign.symbol).font(.system(size: 26)).frame(width: 48, height: 48)
                .background(Theme.surface, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(Theme.serif(18)).foregroundStyle(Theme.text)
                Text("\(p.relationship.uppercased()) · \(p.natalChart.sunSign.name.uppercased())")
                    .font(Theme.mono(9)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(syn.score)%").font(Theme.serif(20)).foregroundStyle(Theme.gold)
                Text("\(guna.total.formatted())/36 GUNA").font(Theme.mono(9)).foregroundStyle(Theme.secondary)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 0.5))
    }
}

struct MatchDetailView: View {
    let me: BirthProfile
    let other: BirthProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store
    @State private var loader = ReadingLoader()
    @State private var editing = false

    var body: some View {
        let syn = Synastry(me.natalChart, other.natalChart)
        let guna = GunaMilan(first: VedicChart(natal: me.natalChart), second: VedicChart(natal: other.natalChart))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    person(me)
                    Spacer()
                    ZStack {
                        Circle().stroke(Theme.hairline, lineWidth: 6)
                        Circle().trim(from: 0, to: CGFloat(syn.score) / 100)
                            .stroke(Theme.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(syn.score)%").font(Theme.serif(24)).foregroundStyle(Theme.text)
                    }
                    .frame(width: 96, height: 96)
                    Spacer()
                    person(other)
                }
                Text(syn.elementNote).font(Theme.serif(15)).foregroundStyle(Theme.secondary)

                Card {
                    HStack {
                        SectionLabel("Kundli Milan")
                        Text("\(guna.total.formatted()) / 36").font(Theme.serif(20)).foregroundStyle(Theme.gold)
                    }
                    Text(guna.verdict.uppercased()).font(Theme.mono(10)).foregroundStyle(Theme.secondary)
                    ForEach(guna.kootas) { k in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(k.name).font(Theme.serif(15)).foregroundStyle(Theme.text)
                                Spacer()
                                Text("\(k.score.formatted())/\(Int(k.max))").font(Theme.mono(11))
                                    .foregroundStyle(k.score == 0 ? Theme.tense : Theme.text)
                            }
                            ProgressView(value: k.score, total: k.max).tint(k.score == 0 ? Theme.tense : Theme.gold)
                            Text(k.meaning).font(Theme.mono(9)).foregroundStyle(Theme.secondary)
                        }
                    }
                }

                Card {
                    SectionLabel("Synastry aspects")
                    ForEach(Array(syn.aspects.prefix(10).enumerated()), id: \.offset) { _, a in
                        HStack {
                            Text("\(a.first.symbol) \(a.type.symbol) \(a.second.symbol)").frame(width: 70, alignment: .leading)
                                .foregroundStyle(a.type.harmony > 0 ? Theme.flowing : a.type.harmony < 0 ? Theme.tense : Theme.gold)
                            Text("Your \(a.first.rawValue) \(a.type.rawValue.lowercased()) their \(a.second.rawValue)")
                                .font(Theme.serif(14)).foregroundStyle(Theme.text)
                        }
                    }
                }

                Card {
                    SectionLabel("Astra's reading")
                    if store.isPro {
                        ReadingBlock(loader: loader) { load(force: true) }
                    } else {
                        Text("Your deep compatibility reading — the core dynamic, emotional bond, friction points and what the Guna score means for you two.")
                            .font(Theme.serif(15)).foregroundStyle(Theme.secondary)
                        Button("Unlock reading ✦") { _ = store.require("Deep compatibility readings are part of AstraAI Pro.") }
                            .buttonStyle(PillButtonStyle(filled: false))
                    }
                }
            }
            .padding(20)
        }
        .astraScreen()
        .navigationTitle(other.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit details") { editing = true }
                    Button("Remove", role: .destructive) {
                        context.delete(other)
                        try? context.save()
                        dismiss()
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack { ProfileForm(mode: .edit(other)) { _ in if store.isPro { load(force: true) } } }
        }
        .onAppear { if store.isPro { load() } }
        .onChange(of: store.isPro) { if store.isPro { load() } }
    }

    private func person(_ p: BirthProfile) -> some View {
        VStack(spacing: 6) {
            Text(p.natalChart.sunSign.symbol).font(.system(size: 30))
            Text(p.name.components(separatedBy: " ").first ?? p.name).font(Theme.serif(16))
            Text(p.natalChart.bigThree.replacingOccurrences(of: " · ", with: "\n"))
                .font(Theme.mono(9)).multilineTextAlignment(.center).foregroundStyle(Theme.secondary)
        }
        .foregroundStyle(Theme.text)
        .frame(width: 100)
    }

    private func load(force: Bool = false) {
        let a = me, b = other
        let syn = Synastry(a.natalChart, b.natalChart)
        let guna = GunaMilan(first: VedicChart(natal: a.natalChart), second: VedicChart(natal: b.natalChart))
        loader.load(key: "match-\(a.id)-\(b.id)",
                    system: { AstrologerPrompts.compatibilitySystem(a, b) },
                    prompt: AstrologerPrompts.compatibilityPrompt(a, b, synastry: syn, guna: guna),
                    context: context, force: force, maxTokens: 1400)
    }
}
