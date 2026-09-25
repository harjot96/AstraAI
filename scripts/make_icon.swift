// Renders AstraAI's app icon and launch logo with CoreGraphics.
//   swift scripts/make_icon.swift
// Outputs into AstraAI/Resources/Assets.xcassets.
import AppKit
import CoreGraphics

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("AstraAI/Resources/Assets.xcassets")

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let night = rgb(9, 9, 14)
let dusk = rgb(40, 32, 74)
let gold = rgb(217, 191, 138)
let goldDeep = rgb(176, 138, 74)
let ivory = rgb(242, 240, 232)

/// Deterministic LCG so the starfield is identical on every run.
struct LCG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(s >> 11) / CGFloat(1 << 53)
    }
}

func draw(size: CGFloat, background: Bool) -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs,
                        // App Store icons must have no alpha channel; the launch logo needs transparency.
                        bitmapInfo: (background ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue)!
    let c = CGPoint(x: size / 2, y: size / 2)
    let u = size / 1024 // design unit

    if background {
        ctx.setFillColor(night)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let glow = CGGradient(colorsSpace: cs, colors: [dusk, night] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: c.x, y: size * 0.72), startRadius: 0,
                               endCenter: CGPoint(x: c.x, y: size * 0.72), endRadius: size * 0.75, options: [.drawsAfterEndLocation])
        var rng = LCG(s: 7)
        for _ in 0..<90 {
            let p = CGPoint(x: rng.next() * size, y: rng.next() * size)
            let r = (0.8 + rng.next() * 2.4) * u
            ctx.setFillColor(rgb(255, 255, 255, 0.25 + rng.next() * 0.55))
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        }
    }

    // Orbits (tilted ellipses)
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y)
    ctx.rotate(by: -0.42)
    ctx.setLineWidth(5 * u)
    for (i, rx) in [400.0, 300.0, 205.0].enumerated() {
        let ry = rx * 0.42
        ctx.setStrokeColor(rgb(217, 191, 138, [0.55, 0.42, 0.3][i]))
        ctx.strokeEllipse(in: CGRect(x: -rx * u, y: -ry * u, width: 2 * rx * u, height: 2 * ry * u))
    }
    // Planets riding the orbits
    let planets: [(CGFloat, CGFloat, CGFloat, CGColor)] = [(400, 0.35, 26, ivory), (300, 3.6, 17, gold), (205, 5.55, 13, ivory)]
    for (rx, angle, r, color) in planets {
        let p = CGPoint(x: rx * u * cos(angle), y: rx * 0.42 * u * sin(angle))
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: p.x - r * u, y: p.y - r * u, width: 2 * r * u, height: 2 * r * u))
    }
    ctx.restoreGState()

    // Central sun: halo + body
    let halo = CGGradient(colorsSpace: cs, colors: [rgb(217, 191, 138, 0.55), rgb(217, 191, 138, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: c, startRadius: 60 * u, endCenter: c, endRadius: 230 * u, options: [])
    let body = CGGradient(colorsSpace: cs, colors: [rgb(250, 232, 190), gold, goldDeep] as CFArray, locations: [0, 0.55, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - 110 * u, y: c.y - 110 * u, width: 220 * u, height: 220 * u))
    ctx.clip()
    ctx.drawRadialGradient(body, startCenter: CGPoint(x: c.x - 35 * u, y: c.y + 40 * u), startRadius: 0,
                           endCenter: c, endRadius: 115 * u, options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // Four-point sparkle, top right
    let s = CGPoint(x: c.x + 250 * u, y: c.y + 250 * u)
    let a = 46 * u, b = 9 * u
    ctx.setFillColor(ivory)
    ctx.move(to: CGPoint(x: s.x, y: s.y + a))
    ctx.addQuadCurve(to: CGPoint(x: s.x + a, y: s.y), control: CGPoint(x: s.x + b, y: s.y + b))
    ctx.addQuadCurve(to: CGPoint(x: s.x, y: s.y - a), control: CGPoint(x: s.x + b, y: s.y - b))
    ctx.addQuadCurve(to: CGPoint(x: s.x - a, y: s.y), control: CGPoint(x: s.x - b, y: s.y - b))
    ctx.addQuadCurve(to: CGPoint(x: s.x, y: s.y + a), control: CGPoint(x: s.x - b, y: s.y + b))
    ctx.fillPath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path)")
}

func writeJSON(_ json: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try json.write(to: url, atomically: true, encoding: .utf8)
}

let info = #"{ "info" : { "author" : "xcode", "version" : 1 } }"#
try writeJSON(info, to: assets.appendingPathComponent("Contents.json"))

// App icon: single 1024 universal image (opaque).
try write(draw(size: 1024, background: true), to: assets.appendingPathComponent("AppIcon.appiconset/icon-1024.png"))
try writeJSON("""
{
  "images" : [ { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""", to: assets.appendingPathComponent("AppIcon.appiconset/Contents.json"))

// Launch logo: transparent artwork, 200pt at @2x/@3x.
try write(draw(size: 400, background: false), to: assets.appendingPathComponent("LaunchLogo.imageset/logo@2x.png"))
try write(draw(size: 600, background: false), to: assets.appendingPathComponent("LaunchLogo.imageset/logo@3x.png"))
try writeJSON("""
{
  "images" : [
    { "idiom" : "universal", "scale" : "1x" },
    { "filename" : "logo@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "logo@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""", to: assets.appendingPathComponent("LaunchLogo.imageset/Contents.json"))

// Launch background color = Theme.background.
try writeJSON("""
{
  "colors" : [ { "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "red" : "0.035", "green" : "0.035", "blue" : "0.055" } }, "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""", to: assets.appendingPathComponent("LaunchBackground.colorset/Contents.json"))
