import AppKit
import Foundation

/// Polls NSPasteboard for changes and calls back with what was captured.
@MainActor
public final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    public var onChange: (@MainActor (ClipboardCapture, String?) -> Void)?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start(interval: TimeInterval = 0.5) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let capture = ClipboardCapture.read(from: pasteboard) else { return }
        onChange?(capture, NSWorkspace.shared.frontmostApplication?.localizedName)
    }
}
