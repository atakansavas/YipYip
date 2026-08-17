import AppKit

/// The menu bar glyph: a clipboard body with a vault dial in the middle, drawn
/// by hand rather than borrowed from SF Symbols so YipYip is recognisable
/// among the other menu bar icons. Rendered as a template image, so macOS tints
/// it for the current menu bar appearance.
enum StatusItemIcon {
    /// Menu bar icons are laid out in an 18pt square.
    private static let side: CGFloat = 18

    /// Outline glyph — the resting state.
    static let idle: NSImage = make(filled: false)
    /// Solid glyph — flashed briefly when a clip is captured.
    static let active: NSImage = make(filled: true)

    private static func make(filled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            draw(filled: filled)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "YipYip"
        return image
    }

    private static let center = NSPoint(x: 9, y: 7.7)

    private static func draw(filled: Bool) {
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
        let dial = NSBezierPath(
            ovalIn: NSRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)
        )
        let hub = NSBezierPath(
            ovalIn: NSRect(x: center.x - 0.55, y: center.y - 0.55, width: 1.1, height: 1.1)
        )
        // Four notches around the dial — what separates a vault dial from a
        // plain circle at this size.
        let notches = notchPath()

        NSColor.black.setFill()
        NSColor.black.setStroke()

        if filled {
            body.fill()
            clip.fill()

            // Knock the dial and its notches back out of the solid body.
            let context = NSGraphicsContext.current
            context?.compositingOperation = .clear
            dial.fill()
            notches.stroke()
            context?.compositingOperation = .sourceOver
            hub.fill()
        } else {
            body.lineWidth = 1.4
            body.stroke()
            clip.fill()
            dial.lineWidth = 1.4
            dial.stroke()
            notches.stroke()
            hub.fill()
        }
    }

    private static func notchPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = 1.1
        path.lineCapStyle = .round

        for degrees in stride(from: 45.0, to: 360.0, by: 90.0) {
            let radians = degrees * .pi / 180
            let direction = NSPoint(x: cos(radians), y: sin(radians))
            path.move(to: NSPoint(
                x: center.x + direction.x * 3.7,
                y: center.y + direction.y * 3.7
            ))
            path.line(to: NSPoint(
                x: center.x + direction.x * 4.7,
                y: center.y + direction.y * 4.7
            ))
        }
        return path
    }
}
