import AstroCore
import Foundation
import UserNotifications

/// Co–Star-style morning nudges. Each of the next 7 days gets its own notification
/// whose text is computed on-device from that day's sky and the user's chart, so no
/// API call is needed. Rescheduled whenever the app becomes active.
enum DailyNotifier {
    static let enabledKey = "astra.dailyNotifications"
    static let hour = 8
    private static let idPrefix = "astra.daily."

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Asks for permission and turns reminders on. Returns whether they're allowed.
    @discardableResult
    static func enable(for profile: BirthProfile) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        UserDefaults.standard.set(granted, forKey: enabledKey)
        if granted { await reschedule(for: profile) }
        return granted
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<7).map { idPrefix + "\($0)" })
    }

    @MainActor
    static func reschedule(for profile: BirthProfile) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<7).map { idPrefix + "\($0)" })
        let natal = profile.natalChart
        let firstName = profile.name.components(separatedBy: " ").first ?? profile.name
        let cal = Calendar.current

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: .now),
                  let fire = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  fire > .now else { continue }
            let content = UNMutableNotificationContent()
            (content.title, content.body) = message(natal: natal, name: firstName, date: fire)
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(identifier: idPrefix + "\(offset)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(request)
        }
    }

    static func message(natal: NatalChart, name: String, date: Date) -> (String, String) {
        let t = TransitReport(natal: natal, date: date)
        let moonSign = t.sign(of: .moon)
        var body = "\(t.moonPhase.emoji) \(t.moonPhase.name) in \(moonSign.name). "
        if let hit = t.toNatal.first(where: { $0.first != .moon }) ?? t.toNatal.first {
            let verb: String
            switch hit.type.harmony {
            case 1: verb = "supports"
            case -1: verb = "challenges"
            default: verb = "activates"
            }
            body += "\(hit.first.rawValue) \(verb) your \(hit.second.rawValue) today."
        } else {
            body += t.moonPhase.guidance
        }
        return ("Good morning, \(name) ✦", body + " Tap for your horoscope.")
    }
}
