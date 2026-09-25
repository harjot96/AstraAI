import Foundation
import Observation
import OSLog
import RevenueCat

/// AstraAI Pro via RevenueCat (same setup as Sprigly): entitlement "pro",
/// offering "default" with monthly + annual packages.
///
/// The paywall is only active when a RevenueCat key is configured
/// (`REVENUECAT_API_KEY` in Config/Secrets.xcconfig). Without one the app is fully free.
///
/// With the paywall on — Free: today's horoscope, charts, 12-sign horoscopes, card of the day,
/// and `freeQuestionsPerDay` astrologer questions. Pro: Claude-powered answers, `proQuestionsPerDay` questions, week/month/year
/// forecasts, full chart & compatibility readings, and multi-card tarot spreads.
@MainActor
@Observable
final class ProStore {
    static let entitlementID = "pro"
    static let freeQuestionsPerDay = 3
    /// Fair-use cap for Pro so the heaviest subscriber still costs less than they pay
    /// (~$0.005 per Claude Haiku question → at most ~$3/month in questions).
    static let proQuestionsPerDay = 20

    /// Master switch; set to false to keep the app free even when a key is present.
    static let subscriptionsOn = true

    /// Public SDK key from Secrets.xcconfig, injected through Info.plist.
    static var apiKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String)?
            .trimmingCharacters(in: .whitespaces)
        return key?.isEmpty == false && key?.hasPrefix("$(") == false ? key : nil
    }

    static var paywallEnabled: Bool { subscriptionsOn && apiKey != nil }

    private(set) var offering: Offering?
    private(set) var hasPurchasedPro = false
    private(set) var isConfigured = false
    private(set) var questionsUsedToday = 0
    var isPurchasing = false
    var errorMessage: String?
    /// Set to present the paywall from anywhere.
    var paywallReason: String?

    private let log = Logger(subsystem: "com.astraai.in", category: "subscriptions")
    private var updates: Task<Void, Never>?

    init() {
        questionsUsedToday = UserDefaults.standard.integer(forKey: Self.quotaKey())
    }

    var isPro: Bool { !Self.paywallEnabled || hasPurchasedPro }

    /// Today's question allowance, or nil when unlimited (app running free).
    var dailyQuestionLimit: Int? {
        guard Self.paywallEnabled else { return nil }
        return hasPurchasedPro ? Self.proQuestionsPerDay : Self.freeQuestionsPerDay
    }

    var questionsLeft: Int { max(0, (dailyQuestionLimit ?? .max) - questionsUsedToday) }

    var canAsk: Bool { dailyQuestionLimit == nil || questionsLeft > 0 }

    /// Monthly + annual packages from the current offering, annual first.
    var packages: [Package] {
        (offering?.availablePackages ?? []).sorted { $0.packageType == .annual && $1.packageType != .annual }
    }

    func recordQuestion() {
        guard dailyQuestionLimit != nil else { return }
        let key = Self.quotaKey()
        questionsUsedToday = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(questionsUsedToday, forKey: key)
    }

    /// Returns true when the feature is available; otherwise shows the paywall.
    func require(_ reason: String) -> Bool {
        if isPro { return true }
        paywallReason = reason
        return false
    }

    /// Call once at launch.
    func configure() {
        questionsUsedToday = UserDefaults.standard.integer(forKey: Self.quotaKey())
        guard Self.subscriptionsOn, !isConfigured, let key = Self.apiKey else {
            if Self.apiKey == nil { log.info("RevenueCat key missing; app runs fully free") }
            return
        }
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: key)
        isConfigured = true
        AIClient.premiumByDefault = false // until the entitlement is confirmed
        AppConfig.subscriberID = Purchases.shared.appUserID
        updates = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task { await loadOffering() }
    }

    func loadOffering() async {
        guard isConfigured else { return }
        do {
            offering = try await Purchases.shared.offerings().current
            if offering?.availablePackages.isEmpty ?? true {
                errorMessage = "Plans aren't available right now. Please try again later."
            }
        } catch {
            errorMessage = "Plans couldn't load. Check your connection and try again."
            log.error("offerings failed: \(error.localizedDescription)")
        }
    }

    func refreshEntitlements() async {
        guard isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
    }

    /// Returns true when the purchase unlocked Pro; false if cancelled or failed.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            if isPro { paywallReason = nil }
            return !result.userCancelled && isPro
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        errorMessage = nil
        do {
            apply(try await Purchases.shared.restorePurchases())
            if isPro {
                paywallReason = nil
            } else {
                errorMessage = "No active AstraAI Pro subscription was found for this Apple ID."
            }
            return isPro
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(_ info: CustomerInfo) {
        AppConfig.subscriberID = info.originalAppUserId
        hasPurchasedPro = info.entitlements[Self.entitlementID]?.isActive == true
        AIClient.premiumByDefault = isPro // Pro gets Claude; free tier uses the free AI
    }

    private static func quotaKey(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "astra.questions.\(c.year!)-\(c.month!)-\(c.day!)"
    }
}
