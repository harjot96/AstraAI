import Foundation

public struct NumerologyProfile: Codable, Hashable, Sendable {
    public let lifePath: Int
    public let expression: Int
    public let soulUrge: Int
    public let personality: Int
    public let birthday: Int
    public let personalYear: Int

    public init(name: String, birthDate: Date, today: Date = .now, calendar: Calendar = .current) {
        let b = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let (y, m, d) = (b.year ?? 2000, b.month ?? 1, b.day ?? 1)
        lifePath = Numerology.reduce(Numerology.reduce(y) + Numerology.reduce(m) + Numerology.reduce(d))
        birthday = Numerology.reduce(d)
        let letters = name.uppercased().filter { $0.isLetter && $0.isASCII }
        let vowels = Set("AEIOU")
        expression = Numerology.reduce(letters.reduce(0) { $0 + Numerology.value($1) })
        soulUrge = Numerology.reduce(letters.filter { vowels.contains($0) }.reduce(0) { $0 + Numerology.value($1) })
        personality = Numerology.reduce(letters.filter { !vowels.contains($0) }.reduce(0) { $0 + Numerology.value($1) })
        let currentYear = calendar.component(.year, from: today)
        personalYear = Numerology.reduce(Numerology.reduce(currentYear) + Numerology.reduce(m) + Numerology.reduce(d),
                                         keepMasters: false)
    }
}

public enum Numerology {
    /// Pythagorean letter value.
    static func value(_ c: Character) -> Int {
        guard let ascii = c.asciiValue, ascii >= 65, ascii <= 90 else { return 0 }
        return Int(ascii - 65) % 9 + 1
    }

    /// Digit-sum reduction, preserving master numbers 11, 22 and 33.
    public static func reduce(_ n: Int, keepMasters: Bool = true) -> Int {
        var x = abs(n)
        while x > 9 && !(keepMasters && [11, 22, 33].contains(x)) {
            x = String(x).compactMap(\.wholeNumberValue).reduce(0, +)
        }
        return x
    }

    public static func meaning(_ n: Int) -> String {
        switch n {
        case 1: "The Leader — independent, pioneering, driven"
        case 2: "The Diplomat — sensitive, cooperative, intuitive"
        case 3: "The Communicator — creative, expressive, social"
        case 4: "The Builder — practical, loyal, disciplined"
        case 5: "The Adventurer — free, curious, adaptable"
        case 6: "The Nurturer — responsible, caring, harmonious"
        case 7: "The Seeker — analytical, spiritual, introspective"
        case 8: "The Powerhouse — ambitious, authoritative, abundant"
        case 9: "The Humanitarian — compassionate, wise, idealistic"
        case 11: "Master 11 — the Intuitive visionary"
        case 22: "Master 22 — the Master Builder"
        case 33: "Master 33 — the Master Teacher"
        default: "—"
        }
    }
}
