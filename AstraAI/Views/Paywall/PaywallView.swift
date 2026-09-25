import RevenueCat
import SwiftUI

/// Co–Star-style upgrade screen. Plans come from the RevenueCat "default" offering,
/// so prices, trials and packages are managed in the RevenueCat dashboard.
struct PaywallView: View {
    let reason: String

    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Package?

    private let features = [
        ("bubble.left.and.text.bubble.right", "\(ProStore.proQuestionsPerDay) questions a day to every astrologer"),
        ("calendar", "Weekly, monthly & yearly forecasts"),
        ("circle.hexagongrid", "Full natal chart & kundli readings"),
        ("heart.circle", "Deep compatibility readings"),
        ("rectangle.portrait.on.rectangle.portrait", "All tarot spreads"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            StarfieldBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OrbitMark().frame(width: 120, height: 120).frame(maxWidth: .infinity)
                    Text("EARLY ACCESS").font(Theme.mono(11)).tracking(2).foregroundStyle(Theme.gold)
                    Text("Join AstraAI Pro").font(Theme.serif(40)).foregroundStyle(Theme.text)
                    Text(reason).font(Theme.serif(17)).foregroundStyle(Theme.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.1) { icon, text in
                            HStack(spacing: 14) {
                                Image(systemName: icon).frame(width: 24).foregroundStyle(Theme.gold)
                                Text(text).font(Theme.serif(16)).foregroundStyle(Theme.text)
                            }
                        }
                    }

                    plans

                    Button {
                        guard let package = selected ?? store.packages.first else { return }
                        Task { await store.purchase(package) }
                    } label: {
                        if store.isPurchasing { ProgressView().tint(Theme.background) } else { Text(ctaTitle) }
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(store.packages.isEmpty || store.isPurchasing)

                    if let error = store.errorMessage {
                        Text(error).font(Theme.mono(11)).foregroundStyle(Theme.tense)
                    }

                    HStack(spacing: 16) {
                        Button("Restore purchases") { Task { await store.restore() } }
                        Spacer()
                        Link("Terms", destination: AppConfig.termsURL)
                        Link("Privacy", destination: AppConfig.privacyURL)
                    }
                    .font(Theme.mono(11))

                    if let product = (selected ?? store.packages.first)?.storeProduct {
                        Text(renewalText(product)).font(Theme.mono(9)).foregroundStyle(Theme.secondary)
                    }
                }
                .padding(24)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text).padding(12)
                    .background(Theme.surface, in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close")
        }
        .task {
            if store.offering == nil { await store.loadOffering() }
            selected = selected ?? store.packages.first
        }
        .onChange(of: store.isPro) { if store.isPro { dismiss() } }
    }

    @ViewBuilder private var plans: some View {
        if store.packages.isEmpty {
            if store.errorMessage == nil { ProgressView().frame(maxWidth: .infinity) }
        } else {
            ForEach(store.packages, id: \.identifier) { package in
                PlanRow(package: package,
                        monthly: store.packages.first { $0.packageType == .monthly },
                        isSelected: (selected ?? store.packages.first)?.identifier == package.identifier)
                    .onTapGesture { selected = package }
            }
        }
    }

    private var ctaTitle: String {
        let product = (selected ?? store.packages.first)?.storeProduct
        return product?.introductoryDiscount?.paymentMode == .freeTrial ? "Start free trial" : "Unlock Pro"
    }

    private func renewalText(_ p: StoreProduct) -> String {
        let period = p.subscriptionPeriod?.unit == .year ? "year" : "month"
        let trial = p.introductoryDiscount.flatMap { $0.paymentMode == .freeTrial ? "Free for \(Self.describe($0.subscriptionPeriod)), then " : nil } ?? ""
        return "\(trial)\(p.localizedPriceString) per \(period). Payment is charged to your Apple ID. Renews automatically unless cancelled at least 24 hours before the period ends. Manage in Settings → Apple ID → Subscriptions."
    }

    static func describe(_ period: SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        return "\(period.value) \(unit)\(period.value == 1 ? "" : "s")"
    }
}

private struct PlanRow: View {
    let package: Package
    let monthly: Package?
    let isSelected: Bool

    private var product: StoreProduct { package.storeProduct }
    private var isAnnual: Bool { package.packageType == .annual }

    /// Percent saved versus paying monthly for a year.
    private var savings: Int? {
        guard isAnnual, let monthly else { return nil }
        let yearOfMonthly = monthly.storeProduct.price * 12
        guard yearOfMonthly > 0 else { return nil }
        let value = NSDecimalNumber(decimal: (1 - product.price / yearOfMonthly) * 100).intValue
        return value > 0 ? value : nil
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(isAnnual ? "ANNUAL" : "MONTHLY").font(Theme.mono(12, weight: .semibold))
                    if let savings {
                        Text("SAVE \(savings)%").font(Theme.mono(9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(Theme.background)
                            .background(Theme.gold, in: Capsule())
                    }
                }
                if let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial {
                    Text("\(PaywallView.describe(intro.subscriptionPeriod)) free trial")
                        .font(Theme.mono(10)).foregroundStyle(Theme.gold)
                } else if isAnnual, let perMonth = product.localizedPricePerMonth {
                    Text("\(perMonth) / mo").font(Theme.mono(10)).foregroundStyle(Theme.gold)
                }
            }
            Spacer()
            Text(product.localizedPriceString).font(Theme.mono(13))
        }
        .foregroundStyle(Theme.text)
        .padding(16)
        .background(isSelected ? Theme.text.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Theme.text : Theme.hairline,
                                                             lineWidth: isSelected ? 1.2 : 0.6))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
