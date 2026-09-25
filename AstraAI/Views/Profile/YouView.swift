import AstroCore
import SwiftData
import SwiftUI

struct YouView: View {
    let me: BirthProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store
    @State private var editing = false
    @State private var confirmReset = false
    @AppStorage(DailyNotifier.enabledKey) private var remindersOn = false

    var body: some View {
        let natal = me.natalChart
        let n = me.numerology
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(me.name).font(Theme.serif(32)).foregroundStyle(Theme.text)
                        Text(birthLine).font(Theme.mono(11)).foregroundStyle(Theme.secondary)
                        Text(natal.bigThree).font(Theme.mono(12)).foregroundStyle(Theme.gold)
                    }
                    .padding(.top, 12)

                    Card {
                        SectionLabel("Numerology")
                        numberRow("Life Path", n.lifePath)
                        numberRow("Expression", n.expression)
                        numberRow("Soul Urge", n.soulUrge)
                        numberRow("Personality", n.personality)
                        numberRow("Personal Year \(Calendar.current.component(.year, from: .now))", n.personalYear)
                    }

                    Card {
                        SectionLabel("Your signs")
                        signRow("Sun", natal.sunSign)
                        signRow("Moon", natal.moonSign)
                        if let r = natal.risingSign { signRow("Rising", r) }
                    }

                    if ProStore.paywallEnabled {
                        Card {
                            SectionLabel("AstraAI Pro")
                            if store.isPro {
                                Text("You're a Pro member ✦").font(Theme.serif(17)).foregroundStyle(Theme.gold)
                                Text("Every reading is unlocked, with \(ProStore.proQuestionsPerDay) astrologer questions a day.")
                                    .font(Theme.serif(14)).foregroundStyle(Theme.secondary)
                            } else {
                                Text("\(store.questionsLeft) of \(ProStore.freeQuestionsPerDay) free questions left today.")
                                    .font(Theme.serif(15)).foregroundStyle(Theme.text)
                                Button("Unlock Pro") { _ = store.require("Unlock every reading and \(ProStore.proQuestionsPerDay) astrologer questions a day.") }
                                    .buttonStyle(PillButtonStyle())
                            }
                            Button("Restore purchases") { Task { await store.restore() } }
                                .font(Theme.mono(11))
                            if let id = AppConfig.subscriberID {
                                Text("SUPPORT ID · \(id)").font(Theme.mono(8)).foregroundStyle(Theme.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    Card {
                        SectionLabel("Settings")
                        Toggle(isOn: Binding(get: { remindersOn }, set: { on in
                            if on { Task { remindersOn = await DailyNotifier.enable(for: me) } }
                            else { DailyNotifier.disable(); remindersOn = false }
                        })) {
                            Text("Daily horoscope at \(DailyNotifier.hour) AM").font(Theme.serif(16))
                        }
                        Hairline()
                        Button("Edit birth details") { editing = true }
                            .font(Theme.serif(16))
                        ShareReadingButton(profile: me, reading: "**\(natal.bigThree)**")
                        Hairline()
                        Button("Clear cached readings") {
                            try? context.delete(model: CachedReading.self)
                            try? context.save()
                        }
                        .font(Theme.serif(16))
                        Button("Reset app", role: .destructive) { confirmReset = true }
                            .font(Theme.serif(16))
                    }

                    HStack(spacing: 16) {
                        Link("Support", destination: AppConfig.supportURL)
                        Link("Privacy", destination: AppConfig.privacyURL)
                        Link("Terms", destination: AppConfig.termsURL)
                    }
                    .font(Theme.mono(11))
                    Text("AstraAI is for reflection and entertainment. It is not a substitute for medical, legal or financial advice.")
                        .font(Theme.mono(9)).foregroundStyle(Theme.secondary)
                }
                .padding(20)
            }
            .astraScreen()
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $editing) { NavigationStack { ProfileForm(mode: .edit(me)) } }
            .confirmationDialog("Delete all profiles, chats and readings?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Reset everything", role: .destructive, action: reset)
            }
        }
    }

    private var birthLine: String {
        let df = DateFormatter()
        df.timeZone = TimeZone(identifier: me.timeZoneID)
        df.dateFormat = me.timeKnown ? "d MMM yyyy · HH:mm" : "d MMM yyyy · time unknown"
        return (df.string(from: me.birthDate) + " · " + me.placeName).uppercased()
    }

    private func numberRow(_ label: String, _ value: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(value)").font(Theme.serif(26)).foregroundStyle(Theme.gold).frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased()).font(Theme.mono(10)).foregroundStyle(Theme.secondary)
                Text(Numerology.meaning(value)).font(Theme.serif(15)).foregroundStyle(Theme.text)
            }
        }
    }

    private func signRow(_ label: String, _ sign: ZodiacSign) -> some View {
        HStack {
            Text(sign.symbol).font(.system(size: 22)).frame(width: 34)
            VStack(alignment: .leading) {
                Text("\(label) in \(sign.name)").font(Theme.serif(16))
                Text("\(sign.element.rawValue) · \(sign.modality.rawValue) · ruled by \(sign.ruler.rawValue)".uppercased())
                    .font(Theme.mono(9)).foregroundStyle(Theme.secondary)
            }
        }
        .foregroundStyle(Theme.text)
    }

    private func reset() {
        DailyNotifier.disable()
        try? context.delete(model: ChatMessage.self)
        try? context.delete(model: CachedReading.self)
        try? context.delete(model: BirthProfile.self)
        try? context.save()
    }
}
