import AstroCore
import SwiftUI

/// Western natal wheel: zodiac ring, house cusps, planet glyphs and aspect lines.
/// The Ascendant sits at 9 o'clock, as in a conventional chart.
struct ChartWheel: View {
    let chart: NatalChart

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let rOuter = side / 2 - 2
            let rSigns = rOuter - side * 0.085
            let rPlanets = rSigns - side * 0.07
            let rInner = rSigns - side * 0.16
            let asc = chart.houses?.ascendant ?? 0

            func point(_ lon: Double, _ r: Double) -> CGPoint {
                let a = (180 + lon - asc) * .pi / 180 // ASC at left, zodiac counter-clockwise
                return CGPoint(x: c.x + r * cos(a), y: c.y - r * sin(a))
            }

            let line = GraphicsContext.Shading.color(Theme.text.opacity(0.35))
            for r in [rOuter, rSigns, rInner] {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: line, lineWidth: 0.6)
            }

            // Zodiac ring
            for sign in ZodiacSign.allCases {
                let start = Double(sign.rawValue) * 30
                var p = Path()
                p.move(to: point(start, rSigns))
                p.addLine(to: point(start, rOuter))
                ctx.stroke(p, with: line, lineWidth: 0.6)
                let glyph = ctx.resolve(Text(sign.symbol).font(.system(size: side * 0.045))
                    .foregroundStyle(Theme.color(for: sign.element.rawValue)))
                ctx.draw(glyph, at: point(start + 15, (rSigns + rOuter) / 2))
            }

            // Houses
            if let houses = chart.houses {
                for (i, cusp) in houses.cusps.enumerated() {
                    var p = Path()
                    p.move(to: point(cusp, 0.22 * side / 2))
                    p.addLine(to: point(cusp, rSigns))
                    let angular = i % 3 == 0
                    ctx.stroke(p, with: .color(Theme.text.opacity(angular ? 0.7 : 0.18)), lineWidth: angular ? 1 : 0.5)
                    let next = houses.cusps[(i + 1) % 12]
                    let mid = cusp + normalize(next - cusp) / 2
                    let num = ctx.resolve(Text("\(i + 1)").font(Theme.mono(side * 0.026))
                        .foregroundStyle(Theme.secondary))
                    ctx.draw(num, at: point(mid, rInner - side * 0.03))
                }
                let ascLabel = ctx.resolve(Text("ASC").font(Theme.mono(side * 0.024, weight: .bold)).foregroundStyle(Theme.gold))
                ctx.draw(ascLabel, at: point(houses.ascendant, rOuter + 0).applying(.init(translationX: 14, y: -10)))
            }

            // Aspect lines
            let bodies = Dictionary(uniqueKeysWithValues: chart.bodies.map { ($0.planet, $0.position.longitude) })
            for asp in chart.aspects where asp.type != .conjunction {
                guard let a = bodies[asp.first], let b = bodies[asp.second] else { continue }
                var p = Path()
                p.move(to: point(a, rInner))
                p.addLine(to: point(b, rInner))
                let color = asp.type.harmony > 0 ? Theme.flowing : Theme.tense
                ctx.stroke(p, with: .color(color.opacity(0.55)), lineWidth: 0.7)
            }

            // Planets, nudged apart when crowded
            let sorted = chart.bodies.filter { $0.planet != .ketu }.sorted { $0.position.longitude < $1.position.longitude }
            var placed: [Double] = []
            for body in sorted {
                var lon = body.position.longitude
                if let last = placed.last, normalize(lon - last) < 7 { lon = last + 7 }
                placed.append(lon)
                let glyph = ctx.resolve(Text(body.planet.symbol).font(.system(size: side * 0.05))
                    .foregroundStyle(Theme.text))
                ctx.draw(glyph, at: point(lon, rPlanets))
                var tick = Path()
                tick.move(to: point(body.position.longitude, rSigns))
                tick.addLine(to: point(body.position.longitude, rSigns - 5))
                ctx.stroke(tick, with: .color(Theme.gold), lineWidth: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// South-Indian style kundli: signs fixed in a 4×4 frame, Pisces top-left, clockwise.
struct SouthIndianChart: View {
    let chart: VedicChart

    /// Grid position (row, col) for each sign index 0 (Aries) … 11 (Pisces).
    private let cells: [(Int, Int)] = [(0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3),
                                       (3, 2), (3, 1), (3, 0), (2, 0), (1, 0), (0, 0)]

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 4
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { sign in
                    let (row, col) = cells[sign]
                    let occupants = chart.placements.filter { $0.rashi.rawValue == sign }
                    let isLagna = chart.lagnaSign?.rawValue == sign
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            let z = ZodiacSign(rawValue: sign)!
                            Text("\(z.symbol) \(z.name.prefix(3).uppercased())")
                                .font(Theme.mono(8)).foregroundStyle(Theme.secondary)
                            Spacer()
                            if isLagna { Text("LAG").font(Theme.mono(8, weight: .bold)).foregroundStyle(Theme.gold) }
                        }
                        ForEach(occupants) { p in
                            Text(p.planet.vedicName.prefix(2) + (p.isRetrograde ? "ᴿ" : ""))
                                .font(Theme.serif(13)).foregroundStyle(Theme.text)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(5)
                    .frame(width: cell, height: cell, alignment: .topLeading)
                    .background(isLagna ? Theme.gold.opacity(0.08) : .clear)
                    .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 0.6))
                    .offset(x: CGFloat(col) * cell, y: CGFloat(row) * cell)
                }
                VStack(spacing: 4) {
                    Text("RASHI").font(Theme.mono(10)).tracking(2).foregroundStyle(Theme.secondary)
                    Text(chart.moonSign.rashiName).font(Theme.serif(20)).foregroundStyle(Theme.text)
                    Text(chart.janmaNakshatra.name).font(Theme.mono(10)).foregroundStyle(Theme.gold)
                }
                .frame(width: cell * 2, height: cell * 2)
                .offset(x: cell, y: cell)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
