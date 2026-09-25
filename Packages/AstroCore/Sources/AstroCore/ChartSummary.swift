import Foundation

/// Compact plain-text renderings of computed charts, used as grounding context
/// for the language model. The model interprets; AstroCore does the math.
public enum ChartSummary {

    public static func natal(_ chart: NatalChart) -> String {
        let b = chart.birth
        let tz = TimeZone(identifier: b.timeZoneID) ?? .current
        let df = DateFormatter()
        df.timeZone = tz
        df.dateFormat = b.timeKnown ? "d MMM yyyy, HH:mm zzz" : "d MMM yyyy (time unknown)"
        var lines = ["WESTERN NATAL CHART (tropical, \(chart.houses?.system.rawValue ?? "no") houses)",
                     "Name: \(b.name)", "Born: \(df.string(from: b.date)) in \(b.placeName)"]
        if let h = chart.houses {
            lines.append("Ascendant: \(describe(h.ascendant)); Midheaven: \(describe(h.midheaven))")
        } else {
            lines.append("Birth time unknown: rising sign and houses are not available; Moon degree is approximate.")
        }
        for body in chart.bodies {
            var s = "- \(body.planet.rawValue): \(describe(body.position.longitude))"
            if let house = body.house { s += ", house \(house)" }
            if body.position.isRetrograde { s += ", retrograde" }
            lines.append(s)
        }
        let bal = chart.balance
        lines.append("Dominant element: \(bal.dominantElement.rawValue); dominant modality: \(bal.dominantModality.rawValue)")
        let top = chart.aspects.prefix(12).map(\.description).joined(separator: "; ")
        lines.append("Major aspects: \(top)")
        return lines.joined(separator: "\n")
    }

    public static func vedic(_ chart: VedicChart, at date: Date = .now) -> String {
        var lines = ["VEDIC CHART (sidereal, Lahiri ayanamsa \(String(format: "%.2f", chart.ayanamsa))°, whole-sign houses)"]
        if let lagna = chart.lagna {
            let sign = ZodiacSign(longitude: lagna)
            lines.append("Lagna: \(sign.rashiName) (\(sign.name)) \(formatDegreeInSign(lagna))")
        }
        let moon = chart.placement(.moon)
        lines.append("Moon sign (Rashi): \(moon.rashi.rashiName); Janma Nakshatra: \(moon.nakshatra.name) pada \(moon.pada), lord \(moon.nakshatra.lord.vedicName)")
        for p in chart.placements {
            var s = "- \(p.planet.vedicName): \(p.rashi.rashiName) \(formatDegreeInSign(p.siderealLongitude)), \(p.nakshatra.name) pada \(p.pada)"
            if let h = p.house { s += ", bhava \(h)" }
            if p.isRetrograde { s += ", vakri" }
            lines.append(s)
        }
        if let current = chart.currentDasha(at: date) {
            let df = DateFormatter()
            df.dateFormat = "MMM yyyy"
            lines.append("Current Vimshottari dasha: \(current.maha.lord.vedicName) mahadasha (until \(df.string(from: current.maha.end))), \(current.antar.lord.vedicName) antardasha (until \(df.string(from: current.antar.end)))")
        }
        lines.append("Mangal dosha: \(chart.isManglik ? "present" : "absent")")
        lines.append("Today's Panchang: \(Panchang(date: date).summary)")
        return lines.joined(separator: "\n")
    }

    public static func transits(_ report: TransitReport) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE d MMMM yyyy"
        var lines = ["SKY ON \(df.string(from: report.date).uppercased())",
                     "Moon phase: \(report.moonPhase.name) (\(Int(report.moonPhase.illumination * 100))% lit)"]
        let sky = report.positions.filter { $0.planet != .ketu }.map { p in
            "\(p.planet.rawValue) \(describe(p.longitude))\(p.isRetrograde ? " Rx" : "")"
        }
        lines.append("Positions: " + sky.joined(separator: ", "))
        if !report.toNatal.isEmpty {
            let hits = report.toNatal.prefix(8).map {
                "transiting \($0.first.rawValue) \($0.type.rawValue.lowercased()) natal \($0.second.rawValue) (orb \(String(format: "%.1f", $0.orb))°)"
            }
            lines.append("Active personal transits: " + hits.joined(separator: "; "))
        }
        return lines.joined(separator: "\n")
    }

    public static func numerology(_ n: NumerologyProfile) -> String {
        "NUMEROLOGY: Life Path \(n.lifePath), Expression \(n.expression), Soul Urge \(n.soulUrge), Personality \(n.personality), Birthday \(n.birthday), Personal Year \(n.personalYear)"
    }

    public static func describe(_ longitude: Double) -> String {
        "\(ZodiacSign(longitude: longitude).name) \(formatDegreeInSign(longitude))"
    }
}
