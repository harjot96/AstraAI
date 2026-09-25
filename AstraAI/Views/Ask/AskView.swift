import SwiftData
import SwiftUI

/// AstroTalk-style entry: pick an astrologer, then chat.
struct AskView: View {
    let me: BirthProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Talk to an AI astrologer")
                        .font(Theme.serif(30)).foregroundStyle(Theme.text)
                        .padding(.top, 12)
                    Text("Each AI astrologer already knows your chart, kundli and today's sky." + (ProStore.paywallEnabled ? "" : " Unlimited questions."))
                        .font(Theme.serif(15)).foregroundStyle(Theme.secondary)
                    ForEach(AstrologerExpert.allCases) { expert in
                        NavigationLink(value: expert) {
                            ExpertRow(expert: expert, profile: me)
                        }
                    }
                }
                .padding(20)
            }
            .astraScreen()
            .navigationBarHidden(true)
            .navigationDestination(for: AstrologerExpert.self) { ChatView(me: me, expert: $0) }
        }
    }
}

private struct ExpertRow: View {
    let expert: AstrologerExpert
    let profile: BirthProfile
    @Query private var messages: [ChatMessage]

    init(expert: AstrologerExpert, profile: BirthProfile) {
        self.expert = expert
        self.profile = profile
        let pid = profile.id
        let tag = expert.rawValue
        _messages = Query(filter: #Predicate<ChatMessage> { $0.profileID == pid && $0.expert == tag },
                          sort: \.createdAt, order: .reverse)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.surface)
                Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 0.8)
                Image(systemName: expert.symbol).font(.system(size: 20)).foregroundStyle(Theme.gold)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expert.name).font(Theme.serif(18)).foregroundStyle(Theme.text)
                    Text("AI").font(Theme.mono(9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .foregroundStyle(Theme.gold)
                        .overlay(Capsule().stroke(Theme.gold.opacity(0.6), lineWidth: 0.6))
                }
                Text(expert.specialty.uppercased()).font(Theme.mono(9)).tracking(0.8).foregroundStyle(Theme.secondary)
                if let last = messages.first {
                    Text(last.text).font(Theme.serif(13)).foregroundStyle(Theme.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text("CHAT").font(Theme.mono(11, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(Theme.background)
                .background(Theme.text, in: Capsule())
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 0.5))
    }
}
