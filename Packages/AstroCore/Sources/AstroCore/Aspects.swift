import Foundation

public enum AspectType: String, CaseIterable, Codable, Sendable {
    case conjunction = "Conjunction"
    case sextile = "Sextile"
    case square = "Square"
    case trine = "Trine"
    case opposition = "Opposition"

    public var angle: Double {
        switch self {
        case .conjunction: 0
        case .sextile: 60
        case .square: 90
        case .trine: 120
        case .opposition: 180
        }
    }

    public var orb: Double {
        switch self {
        case .conjunction, .opposition: 8
        case .square, .trine: 7
        case .sextile: 5
        }
    }

    public var symbol: String {
        switch self {
        case .conjunction: "☌"
        case .sextile: "⚹"
        case .square: "□"
        case .trine: "△"
        case .opposition: "☍"
        }
    }

    /// +1 flowing, -1 tense, 0 blending.
    public var harmony: Int {
        switch self {
        case .trine, .sextile: 1
        case .square, .opposition: -1
        case .conjunction: 0
        }
    }
}

public struct Aspect: Codable, Hashable, Sendable {
    public let first: Planet
    public let second: Planet
    public let type: AspectType
    public let orb: Double

    public var description: String {
        "\(first.rawValue) \(type.rawValue.lowercased()) \(second.rawValue) (orb \(String(format: "%.1f", orb))°)"
    }
}

public enum Aspects {
    /// Aspects between bodies in one chart, or between two charts when `other` is given.
    public static func find(_ bodies: [BodyPosition], against other: [BodyPosition]? = nil,
                            orbScale: Double = 1) -> [Aspect] {
        var result: [Aspect] = []
        let targets = other ?? bodies
        for (i, a) in bodies.enumerated() {
            for (j, b) in targets.enumerated() {
                if other == nil && j <= i { continue }
                // The nodes are always opposite; skip that pair and node-node noise.
                if Set([a.planet, b.planet]) == Set([.rahu, .ketu]) { continue }
                let sep = separation(a.longitude, b.longitude)
                for type in AspectType.allCases {
                    let orb = abs(sep - type.angle)
                    if orb <= type.orb * orbScale {
                        result.append(Aspect(first: a.planet, second: b.planet, type: type, orb: orb))
                        break
                    }
                }
            }
        }
        return result.sorted { $0.orb < $1.orb }
    }
}
