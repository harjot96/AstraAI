import SwiftData
import SwiftUI

struct ChatView: View {
    let me: BirthProfile
    let expert: AstrologerExpert

    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @Query private var messages: [ChatMessage]
    @State private var draft = ""
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var errorMessage: String?
    @State private var task: Task<Void, Never>?
    @State private var userStopped = false
    @FocusState private var focused: Bool

    /// Only the most recent turns are sent, to keep token costs flat.
    private let historyWindow = 16

    init(me: BirthProfile, expert: AstrologerExpert) {
        self.me = me
        self.expert = expert
        let pid = me.id
        let tag = expert.rawValue
        _messages = Query(filter: #Predicate<ChatMessage> { $0.profileID == pid && $0.expert == tag },
                          sort: \.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Bubble(role: "assistant", text: expert.greeting)
                        ForEach(messages) { m in Bubble(role: m.role, text: m.text) }
                        if isStreaming {
                            Bubble(role: "assistant", text: streamingText.isEmpty ? "…" : streamingText)
                        }
                        if let errorMessage {
                            Text(errorMessage).font(Theme.mono(11)).foregroundStyle(Theme.tense)
                        }
                        if messages.isEmpty && !isStreaming { suggestions }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: streamingText) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: messages.count) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            composer
        }
        .astraScreen()
        .navigationTitle(expert.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Clear conversation", role: .destructive, action: clear)
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Try asking")
            ForEach(AstrologerPrompts.starterQuestions, id: \.self) { q in
                Button { send(q) } label: {
                    Text(q).font(Theme.serif(15)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.8))
                }
            }
        }
        .padding(.top, 8)
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let limit = store.dailyQuestionLimit {
                if store.isPro {
                    if store.questionsLeft <= 5 {
                        Text("\(store.questionsLeft) OF \(limit) QUESTIONS LEFT TODAY")
                            .font(Theme.mono(10)).foregroundStyle(Theme.secondary)
                    }
                } else {
                    Button {
                        _ = store.require("Ask up to \(ProStore.proQuestionsPerDay) questions a day, answered by our best AI, with AstraAI Pro.")
                    } label: {
                        Text(store.questionsLeft > 0
                             ? "\(store.questionsLeft) FREE QUESTION\(store.questionsLeft == 1 ? "" : "S") LEFT TODAY · GO PRO"
                             : "DAILY FREE QUESTIONS USED · GO PRO")
                            .font(Theme.mono(10)).foregroundStyle(Theme.gold)
                    }
                }
            }
            inputRow
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.background.opacity(0.95))
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask \(expert.name)…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .font(Theme.serif(16))
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.hairline, lineWidth: 0.5))
            Button {
                if isStreaming { userStopped = true; task?.cancel() } else { send(draft) }
            } label: {
                Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(Theme.background)
                    .background(Theme.text, in: Circle())
            }
            .disabled(!isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        guard store.canAsk else {
            if store.isPro {
                errorMessage = "You've asked \(ProStore.proQuestionsPerDay) questions today — your astrologers will be back tomorrow."
            } else {
                _ = store.require("You've used today's \(ProStore.freeQuestionsPerDay) free questions. Get \(ProStore.proQuestionsPerDay) a day with AstraAI Pro.")
            }
            return
        }
        draft = ""
        errorMessage = nil
        let userMessage = ChatMessage(profileID: me.id, role: "user", text: text, expert: expert.rawValue)
        context.insert(userMessage)
        try? context.save()

        let history = (messages + (messages.contains { $0.id == userMessage.id } ? [] : [userMessage]))
            .suffix(historyWindow)
            .map { AIMessage(role: $0.role, content: $0.text) }
        let system = expert.systemPrompt(for: me)

        isStreaming = true
        userStopped = false
        streamingText = ""
        // Not cancelled when the view disappears: the reply finishes and is saved,
        // like a message arriving while you're on another screen.
        task = Task {
            do {
                for try await chunk in AIClient().stream(system: system, messages: Array(history)) {
                    streamingText += chunk
                }
            } catch is CancellationError {
                if !userStopped && streamingText.isEmpty {
                    errorMessage = "The reply was interrupted. Please ask again."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            if !streamingText.isEmpty {
                store.recordQuestion()
                context.insert(ChatMessage(profileID: me.id, role: "assistant", text: streamingText, expert: expert.rawValue))
                try? context.save()
            }
            streamingText = ""
            isStreaming = false
        }
    }

    private func clear() {
        task?.cancel()
        messages.forEach(context.delete)
        try? context.save()
    }
}

private struct Bubble: View {
    let role: String
    let text: String

    var body: some View {
        if role == "user" {
            HStack {
                Spacer(minLength: 50)
                Text(text).font(Theme.serif(16)).foregroundStyle(Theme.background)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.text, in: RoundedRectangle(cornerRadius: 18))
            }
        } else {
            ReadingText(text: text, size: 16)
                .padding(.trailing, 30)
                .textSelection(.enabled)
        }
    }
}
