import AppKit
import ApplicationServices

/// Returns focus to the app that was frontmost before the search panel opened
/// and synthesizes a Cmd+V there, so the item lands at the user's caret instead
/// of only sitting on the pasteboard.
@MainActor
enum PasteHelper {
    /// Virtual key code for "V".
    private static let vKeyCode: CGKeyCode = 9
    private static var didPromptForAccessibility = false

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Opens the Accessibility pane, already scrolled to the right list.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// True when the app is allowed to post synthetic key events. Shows the
    /// system permission dialog at most once per launch when it is not.
    static func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        guard !didPromptForAccessibility else { return false }
        didPromptForAccessibility = true

        // Spelled out rather than using kAXTrustedCheckOptionPrompt, which is a
        // non-Sendable global under strict concurrency.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Activates `app` and pastes into it. A terminated target is skipped rather
    /// than pasted blindly into whatever happens to be frontmost.
    static func paste(into app: NSRunningApplication) {
        guard !app.isTerminated else { return }

        app.activate()
        Task { @MainActor in
            // Activation is asynchronous — posting too early sends the keystroke
            // to whatever is still frontmost.
            for _ in 0..<25 where !app.isActive {
                try? await Task.sleep(for: .milliseconds(20))
            }
            try? await Task.sleep(for: .milliseconds(40))
            postCommandV()
        }
    }

    private static func postCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        // Set the flags explicitly so modifiers the user may still be holding
        // from the global hotkey do not leak into the synthetic event.
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
