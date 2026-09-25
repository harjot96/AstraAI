import Foundation

public struct MoonPhase: Codable, Hashable, Sendable {
    /// Sun–Moon elongation in degrees, [0, 360).
    public let angle: Double

    public var illumination: Double { (1 - Deg.cos(angle)) / 2 }

    public var name: String {
        switch angle {
        case ..<22.5, 337.5...: "New Moon"
        case ..<67.5: "Waxing Crescent"
        case ..<112.5: "First Quarter"
        case ..<157.5: "Waxing Gibbous"
        case ..<202.5: "Full Moon"
        case ..<247.5: "Waning Gibbous"
        case ..<292.5: "Last Quarter"
        default: "Waning Crescent"
        }
    }

    public var emoji: String {
        ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"][Int(normalize(angle + 22.5) / 45) % 8]
    }

    public var guidance: String {
        switch angle {
        case ..<22.5, 337.5...: "Plant intentions; begin quietly."
        case ..<112.5: "Build momentum; take the first concrete steps."
        case ..<202.5: "Refine, then release — emotions and results peak."
        case ..<292.5: "Share what you've learned; give thanks."
        default: "Rest, clear out, and prepare for the next cycle."
        }
    }
}

public struct TransitReport: Codable, Hashable, Sendable {
    public let date: Date
    public let positions: [BodyPosition]
    public let moonPhase: MoonPhase
    /// Aspects from transiting planets (first) to natal planets (second).
    public let toNatal: [Aspect]

    public init(natal: NatalChart?, date: Date = .now) {
        self.date = date
        let jd = JulianDay.from(date)
        positions = Ephemeris.positions(jd: jd)
        let sun = positions.first { $0.planet == .sun }!.longitude
        let moon = positions.first { $0.planet == .moon }!.longitude
        moonPhase = MoonPhase(angle: normalize(moon - sun))
        if let natal {
            let natalBodies = natal.bodies.map(\.position).filter { $0.planet != .ketu && $0.planet != .rahu }
            let movers = positions.filter { $0.planet != .ketu }
            toNatal = Aspects.find(movers, against: natalBodies, orbScale: 0.4)
        } else {
            toNatal = []
        }
    }

    public var retrogrades: [Planet] {
        positions.filter(\.isRetrograde).map(\.planet).filter { $0 != .rahu && $0 != .ketu }
    }

    public func sign(of planet: Planet) -> ZodiacSign {
        positions.first { $0.planet == planet }!.sign
    }
}
