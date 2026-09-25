import Foundation

public enum HouseSystem: String, CaseIterable, Codable, Sendable {
    case placidus = "Placidus"
    case wholeSign = "Whole Sign"
    case equal = "Equal"
}

public struct HouseCusps: Codable, Hashable, Sendable {
    public let system: HouseSystem
    /// 12 cusp longitudes; index 0 is the 1st house (Ascendant for Placidus/Equal).
    public let cusps: [Double]
    public let ascendant: Double
    public let midheaven: Double

    /// House number (1–12) that contains a longitude.
    public func house(of longitude: Double) -> Int {
        let lon = normalize(longitude)
        for i in 0..<12 {
            let start = cusps[i]
            let end = cusps[(i + 1) % 12]
            let span = normalize(end - start)
            if normalize(lon - start) < span { return i + 1 }
        }
        return 1
    }
}

public enum Houses {

    public static func ascendant(ramc: Double, latitude: Double, obliquity eps: Double) -> Double {
        normalize(Deg.atan2(Deg.cos(ramc), -(Deg.sin(ramc) * Deg.cos(eps) + Deg.tan(latitude) * Deg.sin(eps))))
    }

    public static func midheaven(ramc: Double, obliquity eps: Double) -> Double {
        normalize(Deg.atan2(Deg.sin(ramc), Deg.cos(ramc) * Deg.cos(eps)))
    }

    public static func compute(jd: Double, latitude: Double, longitude: Double,
                               system: HouseSystem) -> HouseCusps {
        let eps = Ephemeris.obliquity(jd: jd)
        let ramc = Ephemeris.localSiderealTime(jd: jd, longitude: longitude)
        let asc = ascendant(ramc: ramc, latitude: latitude, obliquity: eps)
        let mc = midheaven(ramc: ramc, obliquity: eps)

        let cusps: [Double]
        switch system {
        case .wholeSign:
            let first = Double(Int(asc / 30)) * 30
            cusps = (0..<12).map { normalize(first + Double($0) * 30) }
        case .equal:
            cusps = (0..<12).map { normalize(asc + Double($0) * 30) }
        case .placidus:
            cusps = placidus(ramc: ramc, latitude: latitude, eps: eps, asc: asc, mc: mc)
                ?? porphyry(asc: asc, mc: mc)
        }
        return HouseCusps(system: system, cusps: cusps, ascendant: asc, midheaven: mc)
    }

    /// Placidus cusps by iterating on the semi-arc. Returns nil in polar latitudes
    /// where some ecliptic degrees never rise or set.
    static func placidus(ramc: Double, latitude: Double, eps: Double, asc: Double, mc: Double) -> [Double]? {
        func cusp(fraction: Double, diurnal: Bool) -> Double? {
            // Initial guess: equal-ish division in RA.
            var ra = diurnal ? ramc + 90 * fraction : ramc + 180 - 90 * fraction
            var lambda = normalize(Deg.atan2(Deg.sin(ra), Deg.cos(ra) * Deg.cos(eps)))
            for _ in 0..<30 {
                let decl = Deg.asin(Deg.sin(eps) * Deg.sin(lambda))
                let x = -Deg.tan(latitude) * Deg.tan(decl)
                guard abs(x) <= 1 else { return nil }
                let dsa = Deg.acos(x)
                ra = diurnal ? ramc + dsa * fraction : ramc + 180 - (180 - dsa) * fraction
                let next = normalize(Deg.atan2(Deg.sin(ra), Deg.cos(ra) * Deg.cos(eps)))
                if separation(next, lambda) < 1e-7 { lambda = next; break }
                lambda = next
            }
            return lambda
        }
        guard let h11 = cusp(fraction: 1.0 / 3, diurnal: true),
              let h12 = cusp(fraction: 2.0 / 3, diurnal: true),
              let h2 = cusp(fraction: 2.0 / 3, diurnal: false),
              let h3 = cusp(fraction: 1.0 / 3, diurnal: false) else { return nil }
        let ic = normalize(mc + 180)
        let firstHalf = [asc, h2, h3, ic, normalize(h11 + 180), normalize(h12 + 180)]
        let secondHalf = firstHalf.map { normalize($0 + 180) }
        return firstHalf + secondHalf
    }

    /// Porphyry: trisect each quadrant. Used as the high-latitude fallback.
    static func porphyry(asc: Double, mc: Double) -> [Double] {
        let ic = normalize(mc + 180)
        let q1 = normalize(ic - asc) / 3      // ASC → IC
        let q2 = normalize(asc + 180 - ic) / 3 // IC → DSC
        let firstHalf = [asc, normalize(asc + q1), normalize(asc + 2 * q1), ic,
                         normalize(ic + q2), normalize(ic + 2 * q2)]
        return firstHalf + firstHalf.map { normalize($0 + 180) }
    }
}
