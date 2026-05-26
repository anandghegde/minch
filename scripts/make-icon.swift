#!/usr/bin/env swift
import AppKit

// Renders the Minch app icon — a lightning bolt (the name means "lightning" in
// Kannada) in the bolt→current gradient on a dark squircle — into a macOS
// .iconset directory. Run via build-app.sh, then packed with `iconutil`.
//
//   swift scripts/make-icon.swift <output.iconset>

func makeIcon(size pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high

    let S = CGFloat(pixels)
    let space = CGColorSpaceCreateDeviceRGB()

    // --- Squircle background -------------------------------------------------
    let radius = S * 0.2237   // Apple's continuous-corner ratio
    let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                    cornerWidth: radius, cornerHeight: radius, transform: nil)
    cg.saveGState()
    cg.addPath(bg); cg.clip()

    // Dark slate → near-black vertical gradient (matches minchSurfacePrimary).
    let bgGrad = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 1.0),
        CGColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1.0)
    ] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

    // Soft electric glow behind the bolt.
    let halo = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.24, green: 0.48, blue: 1.0, alpha: 0.30),
        CGColor(red: 0.24, green: 0.48, blue: 1.0, alpha: 0.0)
    ] as CFArray, locations: [0, 1])!
    cg.drawRadialGradient(halo,
        startCenter: CGPoint(x: S * 0.5, y: S * 0.60), startRadius: 0,
        endCenter: CGPoint(x: S * 0.5, y: S * 0.60), endRadius: S * 0.62, options: [])
    cg.restoreGState()

    // --- Lightning bolt ------------------------------------------------------
    // Normalized vertices, y-DOWN; flipped to CG's y-up below.
    let pts: [(CGFloat, CGFloat)] = [
        (0.62, 0.07),   // top
        (0.31, 0.55),   // outer left
        (0.48, 0.55),   // inner notch (left)
        (0.39, 0.93),   // bottom tip
        (0.69, 0.45),   // outer right
        (0.52, 0.45),   // inner notch (right)
    ]
    func P(_ p: (CGFloat, CGFloat)) -> CGPoint { CGPoint(x: p.0 * S, y: (1 - p.1) * S) }
    let bolt = CGMutablePath()
    bolt.move(to: P(pts[0]))
    for p in pts.dropFirst() { bolt.addLine(to: P(p)) }
    bolt.closeSubpath()

    // Glow halo around the bolt edge.
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: S * 0.045,
                 color: CGColor(red: 0.36, green: 0.89, blue: 0.97, alpha: 0.9))
    cg.addPath(bolt)
    cg.setFillColor(CGColor(red: 0.36, green: 0.89, blue: 0.97, alpha: 1))
    cg.fillPath()
    cg.restoreGState()

    // Gradient fill: electric blue (top) → cyan (bottom).
    cg.saveGState()
    cg.addPath(bolt); cg.clip()
    let boltGrad = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.32, green: 0.56, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.45, green: 0.94, blue: 0.99, alpha: 1.0)
    ] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(boltGrad,
        start: CGPoint(x: 0, y: S * 0.93), end: CGPoint(x: 0, y: S * 0.07), options: [])
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("png encode failed for \(path)\n".utf8)); return
    }
    try? data.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

// macOS iconset: (filename, pixel size)
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in variants {
    writePNG(makeIcon(size: px), to: "\(out)/\(name)")
}
print("wrote \(variants.count) icon variants to \(out)")
