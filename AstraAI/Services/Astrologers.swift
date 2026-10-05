import Foundation

/// AstroTalk-style roster: the user picks a specialist to chat with. Every expert
/// is the same Haiku model with a different focus layered onto the Astra persona.
enum AstrologerExpert: String, CaseIterable, Identifiable {
    case astra, vedic, love, career, tarot, numerology, palm

    var id: String { rawValue }

    var name: String {
        switch self {
        case .astra: "Astra"
        case .vedic: "Acharya Veda"
        case .love: "Luna"
        case .career: "Sol"
        case .tarot: "Oracle Nyx"
        case .numerology: "Pythia"
        case .palm: "Rhea"
        }
    }

    var specialty: String {
        switch self {
        case .astra: "All-round · Western + Vedic"
        case .vedic: "Kundli · Dasha · Remedies"
        case .love: "Love · Marriage · Synastry"
        case .career: "Career · Finance · Timing"
        case .tarot: "Tarot · Intuitive guidance"
        case .numerology: "Numerology · Names · Cycles"
        case .palm: "Palmistry · Heart, head & life lines"
        }
    }

    var symbol: String {
        switch self {
        case .astra: "sparkles"
        case .vedic: "sun.haze"
        case .love: "heart"
        case .career: "chart.line.uptrend.xyaxis"
        case .tarot: "rectangle.portrait.on.rectangle.portrait"
        case .numerology: "number"
        case .palm: "hand.raised"
        }
    }

    var greeting: String {
        switch self {
        case .astra: "I've read your chart. Ask me anything — love, work, timing, or who you are."
        case .vedic: "Namaste. I've prepared your kundli and current dasha. What would you like to know?"
        case .love: "Your Venus and Moon tell a story. Ask me about love, partners or marriage timing."
        case .career: "Let's look at your 10th house, Saturn and your dasha for work and money."
        case .tarot: "Hold a question in mind, then ask. I'll draw cards and read them against your chart."
        case .numerology: "Your numbers are ready — Life Path, Expression and Personal Year. What shall we explore?"
        case .palm: "Hold up your palm. I'll trace your heart, head, life and fate lines and read what they say."
        }
    }

    var focus: String {
        switch self {
        case .astra:
            return "Answer from whichever tradition best fits the question, blending Western and Vedic where useful."
        case .vedic:
            return "Answer primarily as a traditional Vedic Jyotishi: lagna, rashi, nakshatra, bhavas, Vimshottari dasha/antardasha, yogas, doshas and today's Panchang. Offer simple classical remedies (mantra, charity, fasting day, gemstone with a caution to consult an expert before wearing). Use Sanskrit terms with brief English glosses."
        case .love:
            return "Focus on relationships: Venus, Mars, Moon, the 5th and 7th houses, the Descendant, Navamsa themes, and marriage timing from dashas and Jupiter/Saturn transits. Be emotionally attuned and non-judgmental."
        case .career:
            return "Focus on career and money: Midheaven, 10th/2nd/6th/11th houses, Saturn and Jupiter transits, the running dasha, and practical timing windows. Be concrete and action-oriented; no investment advice."
        case .tarot:
            return "If the message lists cards already drawn in the app, read exactly those cards. Otherwise, when the user asks a question, draw cards by naming them (1 card for simple questions, 3 for past/present/future). Choose cards at random-feeling variety, state upright or reversed, read each, then relate the spread to one or two chart placements. Be clear that the draw is symbolic."
        case .numerology:
            return "Focus on numerology: Life Path, Expression, Soul Urge, Personality, Birthday and Personal Year numbers from the data, plus name-number analysis when asked (Pythagorean system). Connect numbers to the chart where it adds insight."
        case .palm:
            return "Focus on palmistry: read the heart line (emotions, love), head line (mind, decisions), life line (vitality, energy) and fate line (career, purpose) symbolically, then relate them to one or two chart placements. Be clear the reading is symbolic — never diagnose health or predict lifespan from the life line."
        }
    }

    func systemPrompt(for profile: BirthProfile) -> String {
        AstrologerPrompts.persona
            + "\n\nIn this conversation you are \(name), specialist in \(specialty). \(focus)"
            + "\n\n=== USER DATA ===\n" + AstrologerPrompts.context(for: profile)
    }
}
