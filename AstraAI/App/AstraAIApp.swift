import SwiftData
import SwiftUI

@main
struct AstraAIApp: App {
    @State private var store = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
                .task { store.configure() }
        }
        .modelContainer(for: [BirthProfile.self, ChatMessage.self, CachedReading.self])
    }
}

struct RootView: View {
    @Query(filter: #Predicate<BirthProfile> { $0.isPrimary }) private var primary: [BirthProfile]
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if let me = primary.first {
                    MainTabView(me: me)
                } else {
                    OnboardingView()
                }
            }
            .accessibilityHidden(showSplash)
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
        }
    }
}

struct MainTabView: View {
    let me: BirthProfile

    @Environment(ProStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    init(me: BirthProfile) {
        self.me = me
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.background)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.1)
        let item = UITabBarItemAppearance()
        let mono = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        item.normal.titleTextAttributes = [.font: mono, .foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        item.normal.iconColor = UIColor.white.withAlphaComponent(0.45)
        item.selected.titleTextAttributes = [.font: mono, .foregroundColor: UIColor(Theme.text)]
        item.selected.iconColor = UIColor(Theme.text)
        appearance.stackedLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var store = store
        TabView {
            TodayView(me: me)
                .tabItem { Label("TODAY", systemImage: "sun.max") }
            ChartScreen(me: me)
                .tabItem { Label("CHART", systemImage: "circle.hexagongrid") }
            AskView(me: me)
                .tabItem { Label("ASK", systemImage: "bubble.left.and.text.bubble.right") }
            TarotView(me: me)
                .tabItem { Label("TAROT", systemImage: "rectangle.portrait.on.rectangle.portrait") }
            PalmView(me: me)
                .tabItem { Label("PALM", systemImage: "hand.raised") }
            MatchView(me: me)
                .tabItem { Label("MATCH", systemImage: "heart.circle") }
        }
        .sheet(item: Binding(get: { store.paywallReason.map(PaywallReason.init) },
                             set: { store.paywallReason = $0?.text })) { reason in
            PaywallView(reason: reason.text)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await store.refreshEntitlements()
                    await DailyNotifier.reschedule(for: me)
                }
            }
        }
    }
}

private struct PaywallReason: Identifiable {
    let text: String
    var id: String { text }
}
