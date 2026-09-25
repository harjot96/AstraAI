import AstroCore
import Foundation

enum ReadingPeriod: String, CaseIterable, Identifiable {
    case today = "Today", week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }

    /// Cache bucket for the period, so a reading is generated once per period.
    func bucket(for date: Date = .now) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .weekOfYear, .yearForWeekOfYear], from: date)
        switch self {
        case .today: return "\(c.year!)-\(c.month!)-\(c.day!)"
        case .week: return "\(c.yearForWeekOfYear!)-w\(c.weekOfYear!)"
        case .month: return "\(c.year!)-\(c.month!)"
        case .year: return "\(c.year!)"
        }
    }
}

enum AstrologerPrompts {

    static let persona = """
    You are Astra, a warm, insightful astrologer inside the AstraAI app. You are fluent in \
    Western tropical astrology (planets, signs, houses, aspects, transits, progressions), Vedic \
    Jyotish (rashi, lagna, nakshatras, Vimshottari dashas, doshas, remedies, Guna Milan), \
    numerology, and the symbolic language of tarot.

    How you work:
    - The user's charts below were calculated precisely by the app. Treat them as ground truth and \
    cite specific placements (e.g. "your Moon in Scorpio in the 8th house") to justify every insight. \
    Never invent positions, degrees or dates that are not in the data. If something needed is missing \
    (e.g. birth time unknown → no houses or rising sign), say so briefly.
    - Speak directly to the user as "you". Be specific, psychologically perceptive, kind and honest — \
    name challenges constructively and always offer something practical to do.
    - Frame astrology as a tool for reflection, not fate. Do not predict death, serious illness, \
    accidents or disasters. For health, legal, financial or mental-health questions, give the \
    astrological perspective briefly and encourage a qualified professional.
    - Formatting: short paragraphs, **bold** for key placements, simple "- " bullets when listing. \
    No markdown headings or tables. Keep chat replies under about 220 words unless asked for depth.
    """

    static func context(for profile: BirthProfile, now: Date = .now) -> String {
        let natal = profile.natalChart
        let vedic = VedicChart(natal: natal)
        let transits = TransitReport(natal: natal, date: now)
        return [
            ChartSummary.natal(natal),
            ChartSummary.vedic(vedic, at: now),
            ChartSummary.numerology(profile.numerology),
            ChartSummary.transits(transits),
        ].joined(separator: "\n\n")
    }

    static func horoscopePrompt(period: ReadingPeriod, profile: BirthProfile) -> String {
        let focus: String
        switch period {
        case .today:
            focus = "Write today's personal horoscope (150–200 words). Open with a one-line theme in bold. Then cover mood & energy, love & relationships, and work & money, each tied to the active transits and Moon phase. End with a line starting \"Do:\" and one starting \"Avoid:\"."
        case .week:
            focus = "Write this week's personal forecast (220–280 words): the overall theme, the best days and why (use the transits), relationships, career, and one ritual or practice for the week."
        case .month:
            focus = "Write this month's personal forecast (280–350 words): major themes from slow-moving transits, the running Vimshottari dasha, love, career, wellbeing, and key advice."
        case .year:
            focus = "Write a personal outlook for this calendar year (350–450 words): Jupiter and Saturn themes against the natal chart, the current mahadasha/antardasha, numerology Personal Year, opportunities, challenges and three intentions to set."
        }
        return focus + "\nPersonalize everything to \(profile.name)'s charts."
    }

    static func compatibilitySystem(_ a: BirthProfile, _ b: BirthProfile) -> String {
        persona + "\n\n=== PERSON A ===\n" + context(for: a) + "\n\n=== PERSON B ===\n" + context(for: b)
    }

    static func compatibilityPrompt(_ a: BirthProfile, _ b: BirthProfile, synastry: Synastry, guna: GunaMilan) -> String {
        let kootas = guna.kootas.map { "\($0.name) \($0.score.formatted())/\(Int($0.max))" }.joined(separator: ", ")
        let aspects = synastry.aspects.prefix(10).map { "\(a.name)'s \($0.first.rawValue) \($0.type.rawValue.lowercased()) \(b.name)'s \($0.second.rawValue)" }
            .joined(separator: "; ")
        return """
        Give a compatibility reading for \(a.name) (A) and \(b.name) (B), who are: \(b.relationship.lowercased()).
        Computed results — Western synastry harmony score: \(synastry.score)/100. Key cross-aspects: \(aspects).
        Vedic Ashtakoota Guna Milan: \(guna.total.formatted())/36 (\(kootas)). Mangal dosha: A \(VedicChart(natal: a.natalChart).isManglik ? "yes" : "no"), B \(VedicChart(natal: b.natalChart).isManglik ? "yes" : "no").
        Write 250–330 words: the core dynamic, emotional connection (Moons/Venus), communication (Mercury), \
        friction points and how to handle them, and what the Guna Milan result means in practice. \
        Adapt the tone to the relationship type.
        """
    }

    static let starterQuestions = [
        "What does my birth chart say about my personality?",
        "Which career paths suit my chart?",
        "What's my current dasha and what does it bring?",
        "How will love look for me this year?",
        "Why do I feel restless lately?",
        "What gemstone or remedy suits me?",
        "Explain my rising sign in simple words",
        "Pull a tarot card for my day",
    ]
}
