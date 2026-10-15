// Renders the LosNotches app icon (an eclipse in the notch) to a 1024×1024 PNG.
// Usage: swift scripts/icon/render-icon.swift <out.png>
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Flip to top-left origin so the notch geometry reads naturally.
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}

// macOS icon grid: 824 pt squircle centred in 1024.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x000000, 0.45))
ctx.addPath(squircle); ctx.setFillColor(rgb(0x070A1F)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()

// Night sky: indigo at the bottom, near-black at the top where the notch sits.
let sky = CGGradient(colorsSpace: cs, colors: [rgb(0x05061A), rgb(0x12153D), rgb(0x34205A)] as CFArray, locations: [0, 0.6, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

// The notch / eclipse body: hangs from the top edge of the tile.
let notchW: CGFloat = 384, notchH: CGFloat = 196, flare: CGFloat = 34, bottomR: CGFloat = 92
let nx = 512 - notchW / 2, top = tile.minY
let notch = CGMutablePath()
notch.move(to: CGPoint(x: nx - flare, y: top))
notch.addQuadCurve(to: CGPoint(x: nx, y: top + flare), control: CGPoint(x: nx, y: top))
notch.addLine(to: CGPoint(x: nx, y: top + notchH - bottomR))
notch.addQuadCurve(to: CGPoint(x: nx + bottomR, y: top + notchH), control: CGPoint(x: nx, y: top + notchH))
notch.addLine(to: CGPoint(x: nx + notchW - bottomR, y: top + notchH))
notch.addQuadCurve(to: CGPoint(x: nx + notchW, y: top + notchH - bottomR), control: CGPoint(x: nx + notchW, y: top + notchH))
notch.addLine(to: CGPoint(x: nx + notchW, y: top + flare))
notch.addQuadCurve(to: CGPoint(x: nx + notchW + flare, y: top), control: CGPoint(x: nx + notchW, y: top))
notch.closeSubpath()
let centre = CGPoint(x: 512, y: top + notchH * 0.55)

// Sparse stars in the lower sky, kept dim so the corona stays the hero.
var starSeed: UInt64 = 0xA57E5
func srnd() -> CGFloat { starSeed = starSeed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(starSeed >> 33) / CGFloat(1 << 31) }
for _ in 0..<70 {
    let p = CGPoint(x: 110 + 804 * srnd(), y: 520 + 400 * srnd())
    let r = 0.8 + 2.2 * pow(srnd(), 4)
    ctx.setFillColor(rgb(0xFFF4DE, 0.15 + 0.5 * srnd()))
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
}

// Glass sheen on the sky (painted before the notch so the eclipse stays void-black).
let sheen = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.08), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 520), options: [])

// Corona rays: seeded, so the icon is reproducible.
var seed: UInt64 = 0x105_0C4E5
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
ctx.setLineCap(.round)
for _ in 0..<150 {
    let angle = CGFloat.pi * (0.06 + 0.88 * rnd())          // fan downward, below the notch
    let inner = 150 + 60 * rnd()
    let len = 160 + 560 * pow(rnd(), 1.6)
    let warm = rnd()
    let color = warm > 0.82 ? rgb(0xFFF4DE, 0.55) : warm > 0.35 ? rgb(0xFFB238, 0.5) : rgb(0xFF5A1F, 0.45)
    let a = CGPoint(x: centre.x + cos(angle) * inner, y: centre.y + sin(angle) * inner)
    let b = CGPoint(x: centre.x + cos(angle) * (inner + len), y: centre.y + sin(angle) * (inner + len))
    // Fade each ray toward its tip.
    ctx.saveGState()
    ctx.setLineWidth(1.2 + 3.4 * pow(rnd(), 3))
    ctx.move(to: a); ctx.addLine(to: b); ctx.replacePathWithStrokedPath(); ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: [color, color.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: a, end: b, options: [])
    ctx.restoreGState()
}

// Corona glow around the eclipse.
let glow = CGGradient(colorsSpace: cs, colors: [rgb(0xFFB238, 0.95), rgb(0xFF5A1F, 0.55), rgb(0xFF5A1F, 0.0)] as CFArray, locations: [0, 0.35, 1])!
ctx.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 430, options: [])

// Eclipse body with a hot rim.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 46, color: rgb(0xFFB238, 1))
ctx.addPath(notch); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(notch); ctx.setLineWidth(7); ctx.replacePathWithStrokedPath(); ctx.clip()
let rim = CGGradient(colorsSpace: cs, colors: [rgb(0xFFF4DE), rgb(0xFFB238), rgb(0xFF5A1F, 0.2)] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(rim, start: CGPoint(x: 512, y: top + notchH), end: CGPoint(x: 512, y: top), options: [])
ctx.restoreGState()
ctx.addPath(notch); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()   // keep the body pure black inside the rim
ctx.saveGState()
ctx.addPath(notch); ctx.setLineWidth(3.5); ctx.setStrokeColor(rgb(0xFFF4DE, 0.9)); ctx.strokePath()
ctx.restoreGState()

// Four wave bars inside: the app's media pulse.
let heights: [CGFloat] = [46, 86, 62, 104]
for (i, h) in heights.enumerated() {
    let w: CGFloat = 22, gap: CGFloat = 16
    let x = 512 - (4 * w + 3 * gap) / 2 + CGFloat(i) * (w + gap)
    let r = CGRect(x: x, y: top + notchH * 0.56 - h / 2, width: w, height: h)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18, color: rgb(0xFFB238, 0.9))
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: w / 2, cornerHeight: w / 2, transform: nil))
    ctx.clip()
    let bar = CGGradient(colorsSpace: cs, colors: [rgb(0xFFF4DE), rgb(0xFFB238)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bar, start: CGPoint(x: x, y: r.minY), end: CGPoint(x: x, y: r.maxY), options: [])
    ctx.restoreGState()
}

// Hairline edge so it sits well in the Dock.
ctx.restoreGState()
ctx.addPath(squircle); ctx.setLineWidth(3); ctx.setStrokeColor(rgb(0xFFFFFF, 0.12)); ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
