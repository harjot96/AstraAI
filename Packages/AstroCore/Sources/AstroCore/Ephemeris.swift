import Foundation

/// Geocentric, tropical ecliptic position of a body.
public struct BodyPosition: Codable, Hashable, Sendable {
    public let planet: Planet
    /// Ecliptic longitude in degrees, [0, 360), equinox of date.
    public let longitude: Double
    public let latitude: Double
    /// Daily motion in degrees; negative means retrograde.
    public let speed: Double

    public var sign: ZodiacSign { ZodiacSign(longitude: longitude) }
    public var isRetrograde: Bool { speed < 0 && planet != .sun && planet != .moon }
}

/// Low-precision analytic ephemeris (Paul Schlyter's method, with the major
/// perturbation terms). Accuracy is ~1–2 arc-minutes for the planets and a few
/// arc-minutes for the Moon, within 1900–2100: good enough for astrology.
public enum Ephemeris {

    /// Days since 2000 Jan 0.0 UT.
    static func dayNumber(jd: Double) -> Double { jd - 2_451_543.5 }

    public static func obliquity(jd: Double) -> Double {
        23.4393 - 3.563e-7 * dayNumber(jd: jd)
    }

    public static func positions(jd: Double) -> [BodyPosition] {
        let now = rawLongitudes(jd: jd)
        let before = rawLongitudes(jd: jd - 0.5)
        let after = rawLongitudes(jd: jd + 0.5)
        var result: [BodyPosition] = []
        for planet in Planet.allCases {
            guard let pos = now[planet], let b = before[planet], let a = after[planet] else { continue }
            let speed = signedDelta(b.lon, a.lon)
            result.append(BodyPosition(planet: planet, longitude: pos.lon, latitude: pos.lat, speed: speed))
        }
        return result
    }

    public static func position(of planet: Planet, jd: Double) -> BodyPosition {
        positions(jd: jd).first { $0.planet == planet }!
    }

    // MARK: - Core computation

    private struct Elements {
        let N, i, w, a, e, M: Double
    }

    private static func elements(_ planet: Planet, d: Double) -> Elements? {
        switch planet {
        case .mercury:
            return Elements(N: 48.3313 + 3.24587e-5 * d, i: 7.0047 + 5.00e-8 * d, w: 29.1241 + 1.01444e-5 * d,
                            a: 0.387098, e: 0.205635 + 5.59e-10 * d, M: 168.6562 + 4.0923344368 * d)
        case .venus:
            return Elements(N: 76.6799 + 2.46590e-5 * d, i: 3.3946 + 2.75e-8 * d, w: 54.8910 + 1.38374e-5 * d,
                            a: 0.723330, e: 0.006773 - 1.302e-9 * d, M: 48.0052 + 1.6021302244 * d)
        case .mars:
            return Elements(N: 49.5574 + 2.11081e-5 * d, i: 1.8497 - 1.78e-8 * d, w: 286.5016 + 2.92961e-5 * d,
                            a: 1.523688, e: 0.093405 + 2.516e-9 * d, M: 18.6021 + 0.5240207766 * d)
        case .jupiter:
            return Elements(N: 100.4542 + 2.76854e-5 * d, i: 1.3030 - 1.557e-7 * d, w: 273.8777 + 1.64505e-5 * d,
                            a: 5.20256, e: 0.048498 + 4.469e-9 * d, M: 19.8950 + 0.0830853001 * d)
        case .saturn:
            return Elements(N: 113.6634 + 2.38980e-5 * d, i: 2.4886 - 1.081e-7 * d, w: 339.3939 + 2.97661e-5 * d,
                            a: 9.55475, e: 0.055546 - 9.499e-9 * d, M: 316.9670 + 0.0334442282 * d)
        case .uranus:
            return Elements(N: 74.0005 + 1.3978e-5 * d, i: 0.7733 + 1.9e-8 * d, w: 96.6612 + 3.0565e-5 * d,
                            a: 19.18171 - 1.55e-8 * d, e: 0.047318 + 7.45e-9 * d, M: 142.5905 + 0.011725806 * d)
        case .neptune:
            return Elements(N: 131.7806 + 3.0173e-5 * d, i: 1.7700 - 2.55e-7 * d, w: 272.8461 - 6.027e-6 * d,
                            a: 30.05826 + 3.313e-8 * d, e: 0.008606 + 2.15e-9 * d, M: 260.2471 + 0.005995147 * d)
        case .moon:
            return Elements(N: 125.1228 - 0.0529538083 * d, i: 5.1454, w: 318.0634 + 0.1643573223 * d,
                            a: 60.2666, e: 0.054900, M: 115.3654 + 13.0649929509 * d)
        default:
            return nil
        }
    }

    /// Solves Kepler's equation and returns heliocentric (or geocentric for the Moon)
    /// rectangular ecliptic coordinates.
    private static func orbitalPosition(_ el: Elements) -> (x: Double, y: Double, z: Double) {
        let M = normalize(el.M)
        var E = M + (180 / .pi) * el.e * Deg.sin(M) * (1 + el.e * Deg.cos(M))
        for _ in 0..<12 {
            let delta = (E - (180 / .pi) * el.e * Deg.sin(E) - M) / (1 - el.e * Deg.cos(E))
            E -= delta
            if abs(delta) < 1e-7 { break }
        }
        let xv = el.a * (Deg.cos(E) - el.e)
        let yv = el.a * (1 - el.e * el.e).squareRoot() * Deg.sin(E)
        let v = Deg.atan2(yv, xv)
        let r = (xv * xv + yv * yv).squareRoot()
        let vw = v + el.w
        let x = r * (Deg.cos(el.N) * Deg.cos(vw) - Deg.sin(el.N) * Deg.sin(vw) * Deg.cos(el.i))
        let y = r * (Deg.sin(el.N) * Deg.cos(vw) + Deg.cos(el.N) * Deg.sin(vw) * Deg.cos(el.i))
        let z = r * Deg.sin(vw) * Deg.sin(el.i)
        return (x, y, z)
    }

    private static func toSpherical(_ p: (x: Double, y: Double, z: Double)) -> (lon: Double, lat: Double, r: Double) {
        let r = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
        return (normalize(Deg.atan2(p.y, p.x)), Deg.atan2(p.z, (p.x * p.x + p.y * p.y).squareRoot()), r)
    }

    private static func fromSpherical(lon: Double, lat: Double, r: Double) -> (x: Double, y: Double, z: Double) {
        (r * Deg.cos(lon) * Deg.cos(lat), r * Deg.sin(lon) * Deg.cos(lat), r * Deg.sin(lat))
    }

    // swiftlint:disable:next function_body_length
    static func rawLongitudes(jd: Double) -> [Planet: (lon: Double, lat: Double)] {
        let d = dayNumber(jd: jd)
        var out: [Planet: (lon: Double, lat: Double)] = [:]

        // Sun
        let ws = 282.9404 + 4.70935e-5 * d
        let es = 0.016709 - 1.151e-9 * d
        let Ms = normalize(356.0470 + 0.9856002585 * d)
        let sunPos = orbitalPosition(Elements(N: 0, i: 0, w: ws, a: 1, e: es, M: Ms))
        let sun = toSpherical(sunPos)
        out[.sun] = (sun.lon, 0)
        // Sun's geocentric rectangular coords (= -Earth heliocentric).
        let sx = sun.r * Deg.cos(sun.lon), sy = sun.r * Deg.sin(sun.lon)

        // Moon (geocentric) with perturbations.
        let moonEl = elements(.moon, d: d)!
        var moon = toSpherical(orbitalPosition(moonEl))
        let Mm = normalize(moonEl.M)
        let Ls = normalize(Ms + ws)
        let Lm = normalize(moonEl.M + moonEl.w + moonEl.N)
        let D = Lm - Ls
        let F = Lm - moonEl.N
        moon.lon += -1.274 * Deg.sin(Mm - 2 * D) + 0.658 * Deg.sin(2 * D) - 0.186 * Deg.sin(Ms)
            - 0.059 * Deg.sin(2 * Mm - 2 * D) - 0.057 * Deg.sin(Mm - 2 * D + Ms) + 0.053 * Deg.sin(Mm + 2 * D)
            + 0.046 * Deg.sin(2 * D - Ms) + 0.041 * Deg.sin(Mm - Ms) - 0.035 * Deg.sin(D)
            - 0.031 * Deg.sin(Mm + Ms) - 0.015 * Deg.sin(2 * F - 2 * D) + 0.011 * Deg.sin(Mm - 4 * D)
        moon.lat += -0.173 * Deg.sin(F - 2 * D) - 0.055 * Deg.sin(Mm - F - 2 * D)
            - 0.046 * Deg.sin(Mm + F - 2 * D) + 0.033 * Deg.sin(F + 2 * D) + 0.017 * Deg.sin(2 * Mm + F)
        out[.moon] = (normalize(moon.lon), moon.lat)

        // Mean lunar nodes.
        let rahu = normalize(moonEl.N)
        out[.rahu] = (rahu, 0)
        out[.ketu] = (normalize(rahu + 180), 0)

        // Planets.
        let Mj = normalize(elements(.jupiter, d: d)!.M)
        let Msat = normalize(elements(.saturn, d: d)!.M)
        let Mu = normalize(elements(.uranus, d: d)!.M)

        for planet in [Planet.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune] {
            let el = elements(planet, d: d)!
            var helio = toSpherical(orbitalPosition(el))
            switch planet {
            case .jupiter:
                helio.lon += -0.332 * Deg.sin(2 * Mj - 5 * Msat - 67.6) - 0.056 * Deg.sin(2 * Mj - 2 * Msat + 21)
                    + 0.042 * Deg.sin(3 * Mj - 5 * Msat + 21) - 0.036 * Deg.sin(Mj - 2 * Msat)
                    + 0.022 * Deg.cos(Mj - Msat) + 0.023 * Deg.sin(2 * Mj - 3 * Msat + 52)
                    - 0.016 * Deg.sin(Mj - 5 * Msat - 69)
            case .saturn:
                helio.lon += 0.812 * Deg.sin(2 * Mj - 5 * Msat - 67.6) - 0.229 * Deg.cos(2 * Mj - 4 * Msat - 2)
                    + 0.119 * Deg.sin(Mj - 2 * Msat - 3) + 0.046 * Deg.sin(2 * Mj - 6 * Msat - 69)
                    + 0.014 * Deg.sin(Mj - 3 * Msat + 32)
                helio.lat += -0.020 * Deg.cos(2 * Mj - 4 * Msat - 2) + 0.018 * Deg.sin(2 * Mj - 6 * Msat - 49)
            case .uranus:
                helio.lon += 0.040 * Deg.sin(Msat - 2 * Mu + 6) + 0.035 * Deg.sin(Msat - 3 * Mu + 33)
                    - 0.015 * Deg.sin(Mj - Mu + 20)
            default:
                break
            }
            let h = fromSpherical(lon: helio.lon, lat: helio.lat, r: helio.r)
            let geo = toSpherical((h.x + sx, h.y + sy, h.z))
            out[planet] = (geo.lon, geo.lat)
        }

        // Pluto: fitted series (heliocentric, J2000), then precessed to date.
        let S = 50.03 + 0.033459652 * d
        let P = 238.95 + 0.003968789 * d
        let plLon = 238.9508 + 0.00400703 * d
            - 19.799 * Deg.sin(P) + 19.848 * Deg.cos(P) + 0.897 * Deg.sin(2 * P) - 4.956 * Deg.cos(2 * P)
            + 0.610 * Deg.sin(3 * P) + 1.211 * Deg.cos(3 * P) - 0.341 * Deg.sin(4 * P) - 0.190 * Deg.cos(4 * P)
            + 0.128 * Deg.sin(5 * P) - 0.034 * Deg.cos(5 * P) - 0.038 * Deg.sin(6 * P) + 0.031 * Deg.cos(6 * P)
            + 0.020 * Deg.sin(S - P) - 0.010 * Deg.cos(S - P)
        let plLat = -3.9082
            - 5.453 * Deg.sin(P) - 14.975 * Deg.cos(P) + 3.527 * Deg.sin(2 * P) + 1.673 * Deg.cos(2 * P)
            - 1.051 * Deg.sin(3 * P) + 0.328 * Deg.cos(3 * P) + 0.179 * Deg.sin(4 * P) - 0.292 * Deg.cos(4 * P)
            + 0.019 * Deg.sin(5 * P) + 0.100 * Deg.cos(5 * P) - 0.031 * Deg.sin(6 * P) - 0.026 * Deg.cos(6 * P)
            + 0.011 * Deg.cos(S - P)
        let plR = 40.72 + 6.68 * Deg.sin(P) + 6.90 * Deg.cos(P) - 1.18 * Deg.sin(2 * P) - 0.03 * Deg.cos(2 * P)
            + 0.15 * Deg.sin(3 * P) - 0.14 * Deg.cos(3 * P)
        let precession = 3.82394e-5 * (d - 1.5) // J2000.0 is d = 1.5
        let ph = fromSpherical(lon: plLon + precession, lat: plLat, r: plR)
        let pluto = toSpherical((ph.x + sx, ph.y + sy, ph.z))
        out[.pluto] = (pluto.lon, pluto.lat)

        return out
    }

    // MARK: - Sidereal time

    /// Local apparent sidereal time in degrees (RAMC).
    public static func localSiderealTime(jd: Double, longitude: Double) -> Double {
        let t = (jd - 2_451_545.0) / 36_525
        let gmst = 280.46061837 + 360.98564736629 * (jd - 2_451_545.0)
            + 0.000387933 * t * t - t * t * t / 38_710_000
        return normalize(gmst + longitude)
    }
}
