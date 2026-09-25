import Foundation

public enum TarotSuit: String, CaseIterable, Codable, Sendable {
    case wands = "Wands", cups = "Cups", swords = "Swords", pentacles = "Pentacles"

    public var symbol: String {
        switch self {
        case .wands: "✦"
        case .cups: "♡"
        case .swords: "⚔︎"
        case .pentacles: "⛤"
        }
    }

    public var element: Element {
        switch self {
        case .wands: .fire
        case .cups: .water
        case .swords: .air
        case .pentacles: .earth
        }
    }

    var theme: String {
        switch self {
        case .wands: "passion, ambition, creative drive"
        case .cups: "emotions, love, intuition"
        case .swords: "thoughts, truth, conflict"
        case .pentacles: "money, work, the body"
        }
    }
}

public struct TarotCard: Codable, Hashable, Sendable, Identifiable {
    public let id: Int          // 0–21 major, 22–77 minor
    public let name: String
    public let suit: TarotSuit? // nil for Major Arcana
    public let upright: String
    public let reversed: String

    public var isMajor: Bool { suit == nil }

    /// Roman numeral for majors, rank label for minors.
    public var label: String {
        if isMajor { return id == 0 ? "0" : TarotDeck.roman(id) }
        let rank = (id - 22) % 14
        return ["A", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "P", "Kn", "Q", "K"][rank]
    }
}

public struct DrawnCard: Codable, Hashable, Sendable, Identifiable {
    public let card: TarotCard
    public let isReversed: Bool
    public let position: String
    public var id: Int { card.id }

    public var meaning: String { isReversed ? card.reversed : card.upright }
    public var description: String {
        "\(position): \(card.name)\(isReversed ? " (reversed)" : "") — \(meaning)"
    }
}

public enum TarotSpread: String, CaseIterable, Codable, Sendable, Identifiable {
    case daily, yesNo, pastPresentFuture, love, career

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .daily: "Card of the Day"
        case .yesNo: "Yes or No"
        case .pastPresentFuture: "Past · Present · Future"
        case .love: "Love Spread"
        case .career: "Career Spread"
        }
    }

    public var positions: [String] {
        switch self {
        case .daily: ["Today"]
        case .yesNo: ["Answer"]
        case .pastPresentFuture: ["Past", "Present", "Future"]
        case .love: ["You", "Them", "The connection"]
        case .career: ["Situation", "Challenge", "Advice"]
        }
    }

    public var blurb: String {
        switch self {
        case .daily: "One card to set the tone for your day."
        case .yesNo: "Ask a clear question, get a direct answer."
        case .pastPresentFuture: "See where a situation came from and where it's heading."
        case .love: "Your feelings, theirs, and what's between you."
        case .career: "Clarity on work, money and next steps."
        }
    }
}

public enum TarotDeck {
    public static let cards: [TarotCard] = majors + minors

    public static func draw(_ spread: TarotSpread, using rng: inout some RandomNumberGenerator) -> [DrawnCard] {
        var deck = cards
        deck.shuffle(using: &rng)
        return zip(spread.positions, deck).map { position, card in
            DrawnCard(card: card, isReversed: Int.random(in: 0..<100, using: &rng) < 30, position: position)
        }
    }

    public static func draw(_ spread: TarotSpread) -> [DrawnCard] {
        var g = SystemRandomNumberGenerator()
        return draw(spread, using: &g)
    }

    /// Deterministic card of the day for a person, stable across launches.
    public static func dailyCard(seed: String, date: Date = .now, calendar: Calendar = .current) -> DrawnCard {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        var rng = SplitMix64(seed: fnv1a("\(seed)|\(c.year!)-\(c.month!)-\(c.day!)"))
        return draw(.daily, using: &rng)[0]
    }

    static func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return hash
    }

    static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }

    private static let majorData: [(String, String, String)] = [
        ("The Fool", "new beginnings, spontaneity, a leap of faith", "recklessness, hesitation, fear of the unknown"),
        ("The Magician", "willpower, skill, manifesting", "manipulation, untapped talent, scattered energy"),
        ("The High Priestess", "intuition, mystery, inner knowing", "secrets, disconnection from intuition"),
        ("The Empress", "abundance, nurturing, creativity", "dependence, creative block, smothering"),
        ("The Emperor", "structure, authority, stability", "rigidity, control, domination"),
        ("The Hierophant", "tradition, guidance, shared values", "rebellion, questioning convention"),
        ("The Lovers", "love, union, aligned choices", "disharmony, imbalance, misaligned values"),
        ("The Chariot", "determination, victory, momentum", "lack of direction, opposition, frustration"),
        ("Strength", "courage, patience, gentle power", "self-doubt, insecurity, raw emotion"),
        ("The Hermit", "introspection, solitude, wisdom", "isolation, loneliness, withdrawal"),
        ("Wheel of Fortune", "cycles, luck, turning points", "resistance to change, bad luck, delays"),
        ("Justice", "fairness, truth, cause and effect", "dishonesty, unfairness, avoiding accountability"),
        ("The Hanged Man", "surrender, pause, new perspective", "stalling, resistance, indecision"),
        ("Death", "endings, transformation, transition", "fear of change, stagnation, holding on"),
        ("Temperance", "balance, moderation, healing", "excess, imbalance, impatience"),
        ("The Devil", "attachment, temptation, shadow self", "release, breaking free, reclaiming power"),
        ("The Tower", "sudden upheaval, revelation, awakening", "averting disaster, fear of change"),
        ("The Star", "hope, renewal, inspiration", "despair, disconnection, lost faith"),
        ("The Moon", "illusion, dreams, the subconscious", "clarity emerging, releasing fear"),
        ("The Sun", "joy, success, vitality", "temporary gloom, dimmed enthusiasm"),
        ("Judgement", "awakening, reckoning, a calling", "self-doubt, ignoring the call"),
        ("The World", "completion, fulfilment, wholeness", "unfinished business, lack of closure"),
    ]

    private static let majors: [TarotCard] = majorData.enumerated().map { i, d in
        TarotCard(id: i, name: d.0, suit: nil, upright: d.1, reversed: d.2)
    }

    private static let rankData: [(String, String, String)] = [
        ("Ace", "a fresh start in", "blocked beginnings in"),
        ("Two", "choices and partnership in", "indecision or imbalance in"),
        ("Three", "growth and collaboration in", "delays or disconnection in"),
        ("Four", "stability and rest in", "restlessness or stagnation in"),
        ("Five", "challenge and conflict in", "recovery after struggle in"),
        ("Six", "harmony and generosity in", "unequal give-and-take in"),
        ("Seven", "perseverance and strategy in", "doubt or distraction in"),
        ("Eight", "movement and mastery in", "being stuck or rushed in"),
        ("Nine", "near-fulfilment in", "anxiety or excess in"),
        ("Ten", "culmination and heavy completion in", "burden or release in"),
        ("Page", "curiosity and messages about", "immaturity or unreliable news about"),
        ("Knight", "bold action around", "impulsiveness or stalled plans around"),
        ("Queen", "mature, caring mastery of", "insecurity or neglect of"),
        ("King", "leadership and command of", "misused authority over"),
    ]

    private static let minors: [TarotCard] = TarotSuit.allCases.enumerated().flatMap { s, suit in
        rankData.enumerated().map { r, rank in
            TarotCard(id: 22 + s * 14 + r, name: "\(rank.0) of \(suit.rawValue)", suit: suit,
                      upright: "\(rank.1) \(suit.theme)", reversed: "\(rank.2) \(suit.theme)")
        }
    }
}

/// Small deterministic PRNG for reproducible draws.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
