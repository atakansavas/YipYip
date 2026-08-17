#!/usr/bin/env swift

// Draws Resources/AppIcon.icns from code, so the icon is reproducible and
// reviewable in a diff instead of being an opaque binary someone has to trust.
//
// Usage: swift Scripts/generate-icon.swift [output-dir]
// The glyph mirrors Sources/YipYip/StatusItemIcon.swift, scaled up and filled.

import AppKit
import Foundation

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"

/// Draws the icon into the current context, in a `side` × `side` box.
func drawIcon(side: CGFloat) {
    // Big Sur proportions: the rounded square sits inside a 10% margin.
    let inset = side * 0.10
    let squareSide = side - inset * 2
    let square = NSRect(x: inset, y: inset, width: squareSide, height: squareSide)
    let plate = NSBezierPath(
        roundedRect: square,
        xRadius: squareSide * 0.2237,
        yRadius: squareSide * 0.2237
    )

    NSGraphicsContext.saveGraphicsState()
    plate.addClip()
    NSGradient(
        colors: [
            NSColor(srgbRed: 0.36, green: 0.31, blue: 0.93, alpha: 1),  // indigo
            NSColor(srgbRed: 0.55, green: 0.24, blue: 0.91, alpha: 1),  // violet
        ]
    )?.draw(in: square, angle: -60)
    NSGraphicsContext.restoreGraphicsState()

    // The glyph is designed in an 18-unit box; map that onto the plate.
    let glyphBox = squareSide * 0.62
    let scale = glyphBox / 18
    let originX = square.midX - glyphBox / 2
    let originY = square.midY - glyphBox / 2

    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: originX, yBy: originY)
    transform.scale(by: scale)
    transform.concat()

    let body = NSBezierPath(
        roundedRect: NSRect(x: 3.1, y: 1.5, width: 11.8, height: 13.8),
        xRadius: 2.7,
        yRadius: 2.7
    )
    let clip = NSBezierPath(
        roundedRect: NSRect(x: 6.4, y: 13.5, width: 5.2, height: 3.1),
        xRadius: 1.3,
        yRadius: 1.3
    )
    let center = NSPoint(x: 9, y: 7.7)
    let dial = NSBezierPath(ovalIn: NSRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5))
    let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 0.55, y: center.y - 0.55, width: 1.1, height: 1.1))

    let notches = NSBezierPath()
    notches.lineWidth = 1.1
    notches.lineCapStyle = .round
    for degrees in stride(from: 45.0, to: 360.0, by: 90.0) {
        let radians = degrees * .pi / 180
        let direction = NSPoint(x: cos(radians), y: sin(radians))
        notches.move(to: NSPoint(x: center.x + direction.x * 3.7, y: center.y + direction.y * 3.7))
        notches.line(to: NSPoint(x: center.x + direction.x * 4.7, y: center.y + direction.y * 4.7))
    }

    NSColor.white.setFill()
    NSColor.white.setStroke()
    body.lineWidth = 1.4
    body.stroke()
    clip.fill()
    dial.lineWidth = 1.4
    dial.stroke()
    notches.stroke()
    hub.fill()

    NSGraphicsContext.restoreGraphicsState()
}

func png(side: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon(side: CGFloat(side))
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: outputDir).appendingPathComponent("AppIcon.iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

// The set macOS expects: each logical size at 1x and 2x.
for base in [16, 32, 128, 256, 512] {
    try png(side: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(side: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(1)
}

try fileManager.removeItem(at: iconset)
print("Wrote \(outputDir)/AppIcon.icns")
