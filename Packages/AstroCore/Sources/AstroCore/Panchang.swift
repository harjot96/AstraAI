import Foundation

/// The five limbs of the Hindu almanac (Panchang) for a moment in time.
public struct Panchang: Codable, Hashable, Sendable {
    /// 1–30 (1–15 Shukla paksha, 16–30 Krishna paksha).
    public let tithi: Int
    public let nakshatra: Nakshatra
    /// 0–26
    public let yogaIndex: Int
    /// 0–59 half-tithi index.
    public let karanaIndex: Int
    public let weekday: Int // 1 = Sunday … 7 = Saturday

    public init(date: Date, timeZone: TimeZone = .current) {
        let jd = JulianDay.from(date)
        let ayan = VedicChart.lahiriAyanamsa(jd: jd)
        let raw = Ephemeris.rawLongitudes(jd: jd)
        let sun = raw[.sun]!.lon, moon = raw[.moon]!.lon
        let elongation = normalize(moon - sun)
        tithi = Int(elongation / 12) + 1
        karanaIndex = Int(elongation / 6)
        nakshatra = Nakshatra(siderealLongitude: normalize(moon - ayan))
        yogaIndex = Int(normalize(sun + moon - 2 * ayan) / (360.0 / 27)) % 27
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        weekday = cal.component(.weekday, from: date)
    }

    public var paksha: String { tithi <= 15 ? "Shukla" : "Krishna" }

    public var tithiName: String {
        let names = ["Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami",
                     "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi"]
        if tithi == 15 { return "Purnima" }
        if tithi == 30 { return "Amavasya" }
        return names[(tithi - 1) % 15]
    }

    public var yogaName: String {
        ["Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda", "Sukarma", "Dhriti",
         "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra", "Siddhi", "Vyatipata",
         "Variyan", "Parigha", "Shiva", "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra",
         "Vaidhriti"][yogaIndex]
    }

    public var karanaName: String {
        switch karanaIndex {
        case 0: return "Kimstughna"
        case 57: return "Shakuni"
        case 58: return "Chatushpada"
        case 59: return "Naga"
        default:
            return ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti"][(karanaIndex - 1) % 7]
        }
    }

    public var varaName: String {
        ["Ravivara", "Somavara", "Mangalavara", "Budhavara", "Guruvara", "Shukravara", "Shanivara"][weekday - 1]
    }

    public var varaLord: Planet {
        [.sun, .moon, .mars, .mercury, .jupiter, .venus, .saturn][weekday - 1]
    }

    /// Yogas and karana traditionally avoided for new beginnings.
    public var isInauspicious: Bool {
        [5, 8, 9, 12, 14, 16, 18, 26].contains(yogaIndex) || karanaName == "Vishti"
    }

    public var summary: String {
        "Tithi \(paksha) \(tithiName), Nakshatra \(nakshatra.name), Yoga \(yogaName), Karana \(karanaName), Vara \(varaName)"
    }
}
