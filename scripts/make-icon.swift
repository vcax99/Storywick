#!/usr/bin/env swift
// Renders the Storywick app icon — waveform bars flowing into a play triangle,
// lime→green→teal gradient, on near-black with a soft green glow.
//   xcrun swift scripts/make-icon.swift <output.png> [size]
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let size = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 1024.0

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no context") }
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)

let lime  = CGColor(red: 0.639, green: 0.902, blue: 0.208, alpha: 1)
let green = CGColor(red: 0.063, green: 0.725, blue: 0.506, alpha: 1)
let teal  = CGColor(red: 0.024, green: 0.714, blue: 0.831, alpha: 1)

// Background — near-black with a faint green centre glow.
ctx.setFillColor(CGColor(red: 0.016, green: 0.024, blue: 0.024, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let vignette = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 0.06, green: 0.30, blue: 0.24, alpha: 0.55),
    CGColor(red: 0.016, green: 0.024, blue: 0.024, alpha: 0),
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(vignette,
    startCenter: CGPoint(x: size * 0.5, y: size * 0.52), startRadius: 0,
    endCenter: CGPoint(x: size * 0.5, y: size * 0.52), endRadius: size * 0.62,
    options: [])

// --- Build the mark path (bars + rounded triangle), centred ---
func roundedTriangle(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let pts = [CGPoint(x: rect.minX, y: rect.maxY),
               CGPoint(x: rect.maxX, y: rect.midY),
               CGPoint(x: rect.minX, y: rect.minY)]
    let path = CGMutablePath()
    for i in 0..<3 {
        let c = pts[i], p = pts[(i + 2) % 3], n = pts[(i + 1) % 3]
        let vp = CGVector(dx: p.x - c.x, dy: p.y - c.y)
        let vn = CGVector(dx: n.x - c.x, dy: n.y - c.y)
        let lp = max(hypot(vp.dx, vp.dy), 0.001), ln = max(hypot(vn.dx, vn.dy), 0.001)
        let r = min(radius, lp / 2, ln / 2)
        let s = CGPoint(x: c.x + vp.dx / lp * r, y: c.y + vp.dy / lp * r)
        let e = CGPoint(x: c.x + vn.dx / ln * r, y: c.y + vn.dy / ln * r)
        if i == 0 { path.move(to: s) } else { path.addLine(to: s) }
        path.addQuadCurve(to: e, control: c)
    }
    path.closeSubpath()
    return path
}

let bars: [Double] = [0.42, 0.72, 1.0, 0.60]
let barW = size * 0.093
let gap = size * 0.062
let triW = size * 0.22
let maxBarH = size * 0.56
let triH = size * 0.36
let contentW = Double(bars.count) * barW + Double(bars.count) * gap + triW
var x = (size - contentW) / 2

let mark = CGMutablePath()
for f in bars {
    let h = maxBarH * f
    let rect = CGRect(x: x, y: (size - h) / 2, width: barW, height: h)
    mark.addPath(CGPath(roundedRect: rect, cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil))
    x += barW + gap
}
x += gap * 0.3
mark.addPath(roundedTriangle(CGRect(x: x, y: (size - triH) / 2, width: triW, height: triH), radius: size * 0.045))

// Glow pass.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: size * 0.05, color: CGColor(red: 0.10, green: 0.80, blue: 0.55, alpha: 0.9))
ctx.addPath(mark)
ctx.setFillColor(green)
ctx.fillPath()
ctx.restoreGState()

// Gradient fill (diagonal: lime top-left → teal bottom-right).
ctx.saveGState()
ctx.addPath(mark)
ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [lime, green, teal] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(grad,
    start: CGPoint(x: size * 0.30, y: size * 0.80),
    end: CGPoint(x: size * 0.72, y: size * 0.20),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.restoreGState()

guard let img = ctx.makeImage(),
      let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(Int(size))px)")
