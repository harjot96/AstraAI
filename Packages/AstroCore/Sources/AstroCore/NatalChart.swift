import Foundation

public struct BirthData: Codable, Hashable, Sendable {
    public var name: String
    /// Birth moment as an absolute instant (already resolved from local time + time zone).
    public var date: Date
    public var timeKnown: Bool
    public var latitude: Double
    public var longitude: Double
    public var placeName: String
    public var timeZoneID: String

    public init(name: String, date: Date, timeKnown: Bool, latitude: Double, longitude: Double,
                placeName: String, timeZoneID: String) {
        self.name = name
        self.date = date
        self.timeKnown = timeKnown
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.timeZoneID = timeZoneID
    }
}

public struct PlacedBody: Codable, Hashable, Sendable, Identifiable {
    public let position: BodyPosition
    public let house: Int?
    public var id: Planet { position.planet }
    public var planet: Planet { position.planet }
    public var sign: ZodiacSign { position.sign }
}

public struct ElementBalance: Codable, Hashable, Sendable {
    public let elements: [Element: Int]
    public let modalities: [Modality: Int]

    public var dominantElement: Element {
        elements.max { $0.value < $1.value }?.key ?? .fire
    }

    public var dominantModality: Modality {
        modalities.max { $0.value < $1.value }?.key ?? .cardinal
    }
}

/// A Western tropical natal chart.
public struct NatalChart: Codable, Hashable, Sendable {
    public let birth: BirthData
    public let jd: Double
    public let bodies: [PlacedBody]
    /// nil when the birth time is unknown (houses and rising sign are unreliable).
    public let houses: HouseCusps?
    public let aspects: [Aspect]

    public init(birth: BirthData, houseSystem: HouseSystem = .placidus) {
        self.birth = birth
        // Unknown birth time: use local noon, the conventional "solar chart" choice.
        var instant = birth.date
        if !birth.timeKnown, let tz = TimeZone(identifier: birth.timeZoneID) {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            instant = cal.date(bySettingHour: 12, minute: 0, second: 0, of: birth.date) ?? birth.date
        }
        jd = JulianDay.from(instant)
        let positions = Ephemeris.positions(jd: jd)
        let cusps = birth.timeKnown
            ? Houses.compute(jd: jd, latitude: birth.latitude, longitude: birth.longitude, system: houseSystem)
            : nil
        houses = cusps
        bodies = positions.map { PlacedBody(position: $0, house: cusps?.house(of: $0.longitude)) }
        aspects = Aspects.find(positions.filter { $0.planet != .ketu })
    }

    public func body(_ planet: Planet) -> PlacedBody { bodies.first { $0.planet == planet }! }

    public var sunSign: ZodiacSign { body(.sun).sign }
    public var moonSign: ZodiacSign { body(.moon).sign }
    public var risingSign: ZodiacSign? { houses.map { ZodiacSign(longitude: $0.ascendant) } }

    /// "Big three" summary like "☉ Leo · ☽ Pisces · ↑ Virgo".
    public var bigThree: String {
        var s = "☉ \(sunSign.name) · ☽ \(moonSign.name)"
        if let r = risingSign { s += " · ↑ \(r.name)" }
        return s
    }

    public var balance: ElementBalance {
        var e: [Element: Int] = [:], m: [Modality: Int] = [:]
        let personal: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]
        for b in bodies where personal.contains(b.planet) {
            let weight = (b.planet == .sun || b.planet == .moon) ? 2 : 1
            e[b.sign.element, default: 0] += weight
            m[b.sign.modality, default: 0] += weight
        }
        if let r = risingSign {
            e[r.element, default: 0] += 2
            m[r.modality, default: 0] += 2
        }
        return ElementBalance(elements: e, modalities: m)
    }
}
