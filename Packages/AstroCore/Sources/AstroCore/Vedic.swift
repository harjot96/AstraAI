import Foundation

public enum Nakshatra: Int, CaseIterable, Codable, Sendable {
    case ashwini, bharani, krittika, rohini, mrigashira, ardra, punarvasu, pushya, ashlesha
    case magha, purvaPhalguni, uttaraPhalguni, hasta, chitra, swati, vishakha, anuradha, jyeshtha
    case mula, purvaAshadha, uttaraAshadha, shravana, dhanishta, shatabhisha, purvaBhadrapada
    case uttaraBhadrapada, revati

    public static let span = 360.0 / 27

    public init(siderealLongitude lon: Double) {
        self = Nakshatra(rawValue: min(26, Int(normalize(lon) / Nakshatra.span)))!
    }

    public var name: String {
        ["Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra", "Punarvasu", "Pushya",
         "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra", "Swati",
         "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana",
         "Dhanishta", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada", "Revati"][rawValue]
    }

    /// Vimshottari dasha lord.
    public var lord: Planet { Vimshottari.order[rawValue % 9] }

    public var deity: String {
        ["Ashwini Kumaras", "Yama", "Agni", "Brahma", "Soma", "Rudra", "Aditi", "Brihaspati", "Nagas",
         "Pitrs", "Bhaga", "Aryaman", "Savitr", "Vishvakarma", "Vayu", "Indra-Agni", "Mitra", "Indra",
         "Nirriti", "Apas", "Vishvedevas", "Vishnu", "Vasus", "Varuna", "Aja Ekapada",
         "Ahir Budhnya", "Pushan"][rawValue]
    }

    public enum Gana: String, Codable, Sendable { case deva = "Deva", manushya = "Manushya", rakshasa = "Rakshasa" }

    public var gana: Gana {
        let g: [Gana] = [.deva, .manushya, .rakshasa, .manushya, .deva, .manushya, .deva, .deva, .rakshasa,
                         .rakshasa, .manushya, .manushya, .deva, .rakshasa, .deva, .rakshasa, .deva, .rakshasa,
                         .rakshasa, .manushya, .manushya, .deva, .rakshasa, .rakshasa, .manushya, .manushya, .deva]
        return g[rawValue]
    }

    public enum Nadi: String, Codable, Sendable { case adi = "Adi", madhya = "Madhya", antya = "Antya" }

    public var nadi: Nadi {
        [Nadi.adi, .madhya, .antya, .antya, .madhya, .adi][rawValue % 6]
    }

    /// Yoni animal (used in Kundli matching).
    public var yoni: String {
        ["Horse", "Elephant", "Sheep", "Serpent", "Serpent", "Dog", "Cat", "Sheep", "Cat", "Rat", "Rat",
         "Cow", "Buffalo", "Tiger", "Buffalo", "Tiger", "Deer", "Deer", "Dog", "Monkey", "Mongoose",
         "Monkey", "Lion", "Horse", "Lion", "Cow", "Elephant"][rawValue]
    }
}

public struct VedicPlacement: Codable, Hashable, Sendable, Identifiable {
    public let planet: Planet
    public let siderealLongitude: Double
    public let isRetrograde: Bool
    /// Whole-sign house from the Lagna, nil when birth time is unknown.
    public let house: Int?
    public var id: Planet { planet }
    public var rashi: ZodiacSign { ZodiacSign(longitude: siderealLongitude) }
    public var nakshatra: Nakshatra { Nakshatra(siderealLongitude: siderealLongitude) }
    public var pada: Int {
        Int(normalize(siderealLongitude).truncatingRemainder(dividingBy: Nakshatra.span) / (Nakshatra.span / 4)) + 1
    }
}

public struct DashaPeriod: Codable, Hashable, Sendable, Identifiable {
    public let lord: Planet
    public let start: Date
    public let end: Date
    public var id: Date { start }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }
}

public enum Vimshottari {
    public static let order: [Planet] = [.ketu, .venus, .sun, .moon, .mars, .rahu, .jupiter, .saturn, .mercury]
    public static let years: [Planet: Double] = [.ketu: 7, .venus: 20, .sun: 6, .moon: 10, .mars: 7,
                                                 .rahu: 18, .jupiter: 16, .saturn: 19, .mercury: 17]
    static let yearSeconds = 365.2425 * 86_400

    /// Maha dasha sequence starting at birth, covering 120 years.
    public static func mahaDashas(moonSidereal: Double, birth: Date) -> [DashaPeriod] {
        let nak = Nakshatra(siderealLongitude: moonSidereal)
        let traversed = normalize(moonSidereal).truncatingRemainder(dividingBy: Nakshatra.span) / Nakshatra.span
        let startIndex = order.firstIndex(of: nak.lord)!
        var periods: [DashaPeriod] = []
        // Back-date the first dasha so its elapsed part lies before birth.
        var cursor = birth.addingTimeInterval(-traversed * years[nak.lord]! * yearSeconds)
        for k in 0..<9 {
            let lord = order[(startIndex + k) % 9]
            let end = cursor.addingTimeInterval(years[lord]! * yearSeconds)
            periods.append(DashaPeriod(lord: lord, start: cursor, end: end))
            cursor = end
        }
        return periods
    }

    /// Antar dashas (sub-periods) within a maha dasha.
    public static func antarDashas(of maha: DashaPeriod) -> [DashaPeriod] {
        let total = maha.end.timeIntervalSince(maha.start)
        let startIndex = order.firstIndex(of: maha.lord)!
        var cursor = maha.start
        return (0..<9).map { k in
            let lord = order[(startIndex + k) % 9]
            let end = cursor.addingTimeInterval(total * years[lord]! / 120)
            defer { cursor = end }
            return DashaPeriod(lord: lord, start: cursor, end: end)
        }
    }
}

/// Sidereal (Jyotish) chart using the Lahiri ayanamsa and whole-sign houses.
public struct VedicChart: Codable, Hashable, Sendable {
    public let ayanamsa: Double
    public let lagna: Double?
    public let placements: [VedicPlacement]
    public let dashas: [DashaPeriod]

    public static func lahiriAyanamsa(jd: Double) -> Double {
        // 23°51′11″ at J2000, precessing ~50.29″ per year.
        let years = (jd - 2_451_545.0) / 365.25
        return 23.853 + years * 50.29 / 3600
    }

    public init(natal: NatalChart) {
        let ayan = VedicChart.lahiriAyanamsa(jd: natal.jd)
        ayanamsa = ayan
        let lagnaLon = natal.houses.map { normalize($0.ascendant - ayan) }
        lagna = lagnaLon
        let lagnaSign = lagnaLon.map { Int($0 / 30) }
        placements = Planet.vedic.map { planet in
            let pos = natal.body(planet).position
            let sid = normalize(pos.longitude - ayan)
            let house = lagnaSign.map { (Int(sid / 30) - $0 + 12) % 12 + 1 }
            return VedicPlacement(planet: planet, siderealLongitude: sid,
                                  isRetrograde: pos.isRetrograde, house: house)
        }
        let moon = placements.first { $0.planet == .moon }!
        dashas = Vimshottari.mahaDashas(moonSidereal: moon.siderealLongitude, birth: natal.birth.date)
    }

    public func placement(_ planet: Planet) -> VedicPlacement { placements.first { $0.planet == planet }! }

    public var lagnaSign: ZodiacSign? { lagna.map { ZodiacSign(longitude: $0) } }
    public var moonSign: ZodiacSign { placement(.moon).rashi }
    public var janmaNakshatra: Nakshatra { placement(.moon).nakshatra }

    public func currentDasha(at date: Date = .now) -> (maha: DashaPeriod, antar: DashaPeriod)? {
        guard let maha = dashas.first(where: { $0.contains(date) }),
              let antar = Vimshottari.antarDashas(of: maha).first(where: { $0.contains(date) }) else { return nil }
        return (maha, antar)
    }

    /// Mangal dosha: Mars in houses 1, 2, 4, 7, 8 or 12 from the Lagna (falls back to the Moon).
    public var isManglik: Bool {
        let mars = placement(.mars)
        let house = mars.house ?? ((Int(mars.siderealLongitude / 30) - moonSign.rawValue + 12) % 12 + 1)
        return [1, 2, 4, 7, 8, 12].contains(house)
    }

    /// Classical gemstone for the Lagna lord (or Moon-sign lord when the time is unknown).
    public var suggestedGemstone: (planet: Planet, stone: String) {
        let lord = (lagnaSign ?? moonSign).ruler
        let stones: [Planet: String] = [.sun: "Ruby", .moon: "Pearl", .mars: "Red Coral", .mercury: "Emerald",
                                        .jupiter: "Yellow Sapphire", .venus: "Diamond / White Sapphire",
                                        .saturn: "Blue Sapphire", .rahu: "Hessonite", .ketu: "Cat's Eye"]
        return (lord, stones[lord] ?? "Pearl")
    }
}
