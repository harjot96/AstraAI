import Foundation

/// Degree-based trig helpers. All astronomical angles in AstroCore are degrees.
enum Deg {
    static let rad = Double.pi / 180

    static func sin(_ d: Double) -> Double { Foundation.sin(d * rad) }
    static func cos(_ d: Double) -> Double { Foundation.cos(d * rad) }
    static func tan(_ d: Double) -> Double { Foundation.tan(d * rad) }
    static func asin(_ x: Double) -> Double { Foundation.asin(x) / rad }
    static func acos(_ x: Double) -> Double { Foundation.acos(x) / rad }
    static func atan2(_ y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) / rad }
}

/// Normalizes an angle into [0, 360).
public func normalize(_ angle: Double) -> Double {
    let r = angle.truncatingRemainder(dividingBy: 360)
    return r < 0 ? r + 360 : r
}

/// Smallest separation between two ecliptic longitudes, in [0, 180].
public func separation(_ a: Double, _ b: Double) -> Double {
    let d = abs(normalize(a) - normalize(b))
    return d > 180 ? 360 - d : d
}

/// Signed shortest difference b - a, in (-180, 180].
func signedDelta(_ a: Double, _ b: Double) -> Double {
    var d = normalize(b - a)
    if d > 180 { d -= 360 }
    return d
}

public enum JulianDay {
    /// Julian Day (UT) for a moment in time.
    public static func from(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    public static func toDate(_ jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
    }
}

/// Formats a longitude as "14°32′" within its sign.
public func formatDegreeInSign(_ longitude: Double) -> String {
    let inSign = normalize(longitude).truncatingRemainder(dividingBy: 30)
    var deg = Int(inSign)
    var min = Int(((inSign - Double(deg)) * 60).rounded())
    if min == 60 { deg += 1; min = 0 }
    return "\(deg)°\(String(format: "%02d", min))′"
}
