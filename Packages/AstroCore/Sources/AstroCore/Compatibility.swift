import Foundation

public struct KootaScore: Codable, Hashable, Sendable, Identifiable {
    public let name: String
    public let score: Double
    public let max: Double
    public let meaning: String
    public var id: String { name }
}

/// Ashtakoota Guna Milan (36-point Vedic match) based on each person's Moon.
/// `first` plays the traditional "groom" role and `second` the "bride" role
/// for the three asymmetric kootas (Varna, Vashya, Gana).
public struct GunaMilan: Codable, Hashable, Sendable {
    public let kootas: [KootaScore]
    public var total: Double { kootas.reduce(0) { $0 + $1.score } }

    public var verdict: String {
        switch total {
        case ..<18: "Below the traditional 18-point threshold"
        case ..<25: "Good match"
        case ..<32: "Very good match"
        default: "Excellent match"
        }
    }

    public init(first a: VedicChart, second b: VedicChart) {
        let ma = a.placement(.moon), mb = b.placement(.moon)
        let sa = ma.rashi, sb = mb.rashi
        let na = ma.nakshatra, nb = mb.nakshatra

        // 1. Varna
        // Brahmin 3 (water), Kshatriya 2 (fire), Vaishya 1 (earth), Shudra 0 (air).
        let varnaRank: (ZodiacSign) -> Int = { [2, 1, 0, 3][$0.rawValue % 4] }
        let varna: Double = varnaRank(sa) >= varnaRank(sb) ? 1 : 0

        // 2. Vashya
        let vashya = GunaMilan.vashyaTable[GunaMilan.vashyaGroup(ma)][GunaMilan.vashyaGroup(mb)]

        // 3. Tara
        func taraOK(_ from: Nakshatra, _ to: Nakshatra) -> Bool {
            let r = ((to.rawValue - from.rawValue + 27) % 27 + 1) % 9
            return ![3, 5, 7].contains(r)
        }
        let tara = (taraOK(nb, na) ? 1.5 : 0) + (taraOK(na, nb) ? 1.5 : 0)

        // 4. Yoni
        let yoni: Double
        if na.yoni == nb.yoni { yoni = 4 }
        else if GunaMilan.yoniEnemies.contains(Set([na.yoni, nb.yoni])) { yoni = 0 }
        else { yoni = 2 }

        // 5. Graha Maitri
        let maitri = GunaMilan.maitri(sa.ruler, sb.ruler)

        // 6. Gana
        let ganaIndex: (Nakshatra.Gana) -> Int = { [.deva: 0, .manushya: 1, .rakshasa: 2][$0]! }
        let ganaTable: [[Double]] = [[6, 6, 1], [5, 6, 0], [1, 0, 6]]
        let gana = ganaTable[ganaIndex(na.gana)][ganaIndex(nb.gana)]

        // 7. Bhakoot
        let dist = (sb.rawValue - sa.rawValue + 12) % 12 + 1
        let pair = Set([dist, dist == 1 ? 1 : 14 - dist])
        let badPairs: [Set<Int>] = [[2, 12], [5, 9], [6, 8]]
        let bhakoot: Double = badPairs.contains(pair) ? 0 : 7

        // 8. Nadi
        let nadi: Double = na.nadi == nb.nadi ? 0 : 8

        kootas = [
            KootaScore(name: "Varna", score: varna, max: 1, meaning: "Spiritual & ego compatibility"),
            KootaScore(name: "Vashya", score: vashya, max: 2, meaning: "Mutual attraction & influence"),
            KootaScore(name: "Tara", score: tara, max: 3, meaning: "Birth-star harmony & wellbeing"),
            KootaScore(name: "Yoni", score: yoni, max: 4, meaning: "Physical & intimate compatibility"),
            KootaScore(name: "Graha Maitri", score: maitri, max: 5, meaning: "Mental wavelength & friendship"),
            KootaScore(name: "Gana", score: gana, max: 6, meaning: "Temperament match"),
            KootaScore(name: "Bhakoot", score: bhakoot, max: 7, meaning: "Emotional bond & family welfare"),
            KootaScore(name: "Nadi", score: nadi, max: 8, meaning: "Health & genetic harmony"),
        ]
    }

    /// 0 Chatushpada, 1 Manava, 2 Jalachara, 3 Vanachara, 4 Keeta.
    static func vashyaGroup(_ moon: VedicPlacement) -> Int {
        let inSign = moon.siderealLongitude.truncatingRemainder(dividingBy: 30)
        switch moon.rashi {
        case .aries, .taurus: return 0
        case .gemini, .virgo, .libra, .aquarius: return 1
        case .cancer, .pisces: return 2
        case .leo: return 3
        case .scorpio: return 4
        case .sagittarius: return inSign < 15 ? 1 : 0
        case .capricorn: return inSign < 15 ? 0 : 2
        }
    }

    static let vashyaTable: [[Double]] = [
        [2, 1, 1, 0.5, 1],
        [1, 2, 0.5, 0, 1],
        [1, 0.5, 2, 1, 1],
        [0.5, 0, 1, 2, 0],
        [1, 1, 1, 0, 2],
    ]

    static let yoniEnemies: [Set<String>] = [
        ["Horse", "Buffalo"], ["Elephant", "Lion"], ["Sheep", "Monkey"], ["Serpent", "Mongoose"],
        ["Dog", "Deer"], ["Cat", "Rat"], ["Cow", "Tiger"],
    ]

    /// Natural friendship: 1 friend, 0 neutral, -1 enemy.
    static func relation(_ p: Planet, to q: Planet) -> Int {
        let friends: [Planet: Set<Planet>] = [
            .sun: [.moon, .mars, .jupiter], .moon: [.sun, .mercury], .mars: [.sun, .moon, .jupiter],
            .mercury: [.sun, .venus], .jupiter: [.sun, .moon, .mars], .venus: [.mercury, .saturn],
            .saturn: [.mercury, .venus],
        ]
        let enemies: [Planet: Set<Planet>] = [
            .sun: [.venus, .saturn], .moon: [], .mars: [.mercury], .mercury: [.moon],
            .jupiter: [.mercury, .venus], .venus: [.sun, .moon], .saturn: [.sun, .moon, .mars],
        ]
        if friends[p]?.contains(q) == true { return 1 }
        if enemies[p]?.contains(q) == true { return -1 }
        return 0
    }

    static func maitri(_ a: Planet, _ b: Planet) -> Double {
        if a == b { return 5 }
        let pair = [relation(a, to: b), relation(b, to: a)].sorted()
        switch (pair[0], pair[1]) {
        case (1, 1): return 5
        case (0, 1): return 4
        case (0, 0): return 3
        case (-1, 1): return 1
        case (-1, 0): return 0.5
        default: return 0
        }
    }
}

/// Western synastry: cross-chart aspects rolled into a 0–100 harmony score.
public struct Synastry: Codable, Hashable, Sendable {
    public let aspects: [Aspect]
    public let score: Int
    public let elementNote: String

    public init(_ a: NatalChart, _ b: NatalChart) {
        let key: Set<Planet> = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]
        let pa = a.bodies.map(\.position).filter { key.contains($0.planet) }
        let pb = b.bodies.map(\.position).filter { key.contains($0.planet) }
        let found = Aspects.find(pa, against: pb, orbScale: 0.75)
        aspects = found

        var raw = 50.0
        for asp in found {
            let weight = [Planet.sun, .moon, .venus, .mars].contains(asp.first)
                && [Planet.sun, .moon, .venus, .mars].contains(asp.second) ? 4.0 : 2.0
            let closeness = 1 - asp.orb / (asp.type.orb * 0.75)
            switch asp.type.harmony {
            case 1: raw += weight * (0.5 + closeness)
            case -1: raw -= weight * 0.6 * (0.5 + closeness)
            default:
                let tense: Set<Planet> = [.saturn, .mars]
                raw += (tense.contains(asp.first) || tense.contains(asp.second) ? 0.5 : 1.5) * weight
            }
        }
        score = Int(min(98, max(12, raw)).rounded())

        let ea = a.balance.dominantElement, eb = b.balance.dominantElement
        let compatible: Set<Set<Element>> = [[.fire, .air], [.earth, .water]]
        if ea == eb {
            elementNote = "You share a dominant \(ea.rawValue) nature — instinctively understood, but you can amplify each other's blind spots."
        } else if compatible.contains(Set([ea, eb])) {
            elementNote = "\(ea.rawValue) and \(eb.rawValue) feed each other — a naturally supportive combination."
        } else {
            elementNote = "\(ea.rawValue) meets \(eb.rawValue): different operating systems that can balance each other with patience."
        }
    }
}
