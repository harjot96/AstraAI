import Foundation

public enum Element: String, CaseIterable, Codable, Sendable {
    case fire = "Fire", earth = "Earth", air = "Air", water = "Water"
}

public enum Modality: String, CaseIterable, Codable, Sendable {
    case cardinal = "Cardinal", fixed = "Fixed", mutable = "Mutable"
}

public enum ZodiacSign: Int, CaseIterable, Codable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces

    public init(longitude: Double) {
        self = ZodiacSign(rawValue: Int(normalize(longitude) / 30) % 12)!
    }

    public var name: String {
        ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio",
         "Sagittarius", "Capricorn", "Aquarius", "Pisces"][rawValue]
    }

    /// Vedic (Sanskrit) rashi name.
    public var rashiName: String {
        ["Mesha", "Vrishabha", "Mithuna", "Karka", "Simha", "Kanya", "Tula", "Vrishchika",
         "Dhanu", "Makara", "Kumbha", "Meena"][rawValue]
    }

    public var symbol: String {
        ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"][rawValue]
    }

    public var element: Element {
        [.fire, .earth, .air, .water][rawValue % 4]
    }

    public var modality: Modality {
        [.cardinal, .fixed, .mutable][rawValue % 3]
    }

    /// Traditional ruler (used by both Western traditional and Vedic systems).
    public var ruler: Planet {
        [.mars, .venus, .mercury, .moon, .sun, .mercury, .venus, .mars,
         .jupiter, .saturn, .saturn, .jupiter][rawValue]
    }

    public var dateRange: String {
        ["Mar 21 – Apr 19", "Apr 20 – May 20", "May 21 – Jun 20", "Jun 21 – Jul 22",
         "Jul 23 – Aug 22", "Aug 23 – Sep 22", "Sep 23 – Oct 22", "Oct 23 – Nov 21",
         "Nov 22 – Dec 21", "Dec 22 – Jan 19", "Jan 20 – Feb 18", "Feb 19 – Mar 20"][rawValue]
    }
}

public enum Planet: String, CaseIterable, Codable, Sendable {
    case sun = "Sun", moon = "Moon", mercury = "Mercury", venus = "Venus", mars = "Mars"
    case jupiter = "Jupiter", saturn = "Saturn", uranus = "Uranus", neptune = "Neptune", pluto = "Pluto"
    case rahu = "North Node", ketu = "South Node"

    public var symbol: String {
        switch self {
        case .sun: "☉"
        case .moon: "☽"
        case .mercury: "☿"
        case .venus: "♀"
        case .mars: "♂"
        case .jupiter: "♃"
        case .saturn: "♄"
        case .uranus: "♅"
        case .neptune: "♆"
        case .pluto: "♇"
        case .rahu: "☊"
        case .ketu: "☋"
        }
    }

    /// Name used in Jyotish.
    public var vedicName: String {
        switch self {
        case .sun: "Surya"
        case .moon: "Chandra"
        case .mercury: "Budha"
        case .venus: "Shukra"
        case .mars: "Mangal"
        case .jupiter: "Guru"
        case .saturn: "Shani"
        case .rahu: "Rahu"
        case .ketu: "Ketu"
        case .uranus, .neptune, .pluto: rawValue
        }
    }

    /// The nine grahas used in Vedic astrology.
    public static let vedic: [Planet] = [.sun, .moon, .mars, .mercury, .jupiter, .venus, .saturn, .rahu, .ketu]

    /// Short keywords handed to the model and shown in the UI.
    public var keywords: String {
        switch self {
        case .sun: "identity, vitality, purpose"
        case .moon: "emotions, needs, instincts"
        case .mercury: "mind, communication, learning"
        case .venus: "love, beauty, values"
        case .mars: "drive, courage, desire"
        case .jupiter: "growth, luck, wisdom"
        case .saturn: "discipline, limits, maturity"
        case .uranus: "change, freedom, originality"
        case .neptune: "dreams, intuition, illusion"
        case .pluto: "power, transformation, depth"
        case .rahu: "ambition, destiny, hunger"
        case .ketu: "past gifts, detachment, spirituality"
        }
    }
}
