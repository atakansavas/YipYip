import Foundation

/// Bridges the two ways macOS talks about a shortcut: Cocoa's `NSEvent`
/// modifier flags, which the recorder receives, and the Carbon masks that
/// `RegisterEventHotKey` requires. Kept out of the UI layer so the mapping is
/// testable without a running app.
public enum HotkeyDescription {
    /// `NSEvent.ModifierFlags` raw values, spelled out so Core needs no AppKit.
    public enum CocoaFlag {
        public static let shift: UInt = 1 << 17
        public static let control: UInt = 1 << 18
        public static let option: UInt = 1 << 19
        public static let command: UInt = 1 << 20
    }

    /// Converts Cocoa modifier flags to the Carbon mask stored in settings.
    public static func carbonModifiers(fromCocoa flags: UInt) -> UInt32 {
        var carbon: UInt32 = 0
        if flags & CocoaFlag.command != 0 { carbon |= HotkeyModifiers.command }
        if flags & CocoaFlag.shift != 0 { carbon |= HotkeyModifiers.shift }
        if flags & CocoaFlag.option != 0 { carbon |= HotkeyModifiers.option }
        if flags & CocoaFlag.control != 0 { carbon |= HotkeyModifiers.control }
        return carbon
    }

    /// A shortcut needs a modifier that apps do not produce by typing, or it
    /// would fire on every keystroke. Shift alone does not qualify.
    public static func isUsable(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let anchoring = HotkeyModifiers.command | HotkeyModifiers.option | HotkeyModifiers.control
        guard modifiers & anchoring != 0 else { return false }
        return keyName(for: keyCode) != nil
    }

    /// Renders a shortcut the way macOS menus do: "⌘⌥V".
    public static func display(keyCode: UInt32, modifiers: UInt32) -> String {
        var text = ""
        // Apple's documented order for modifier glyphs.
        if modifiers & HotkeyModifiers.control != 0 { text += "\u{2303}" }
        if modifiers & HotkeyModifiers.option != 0 { text += "\u{2325}" }
        if modifiers & HotkeyModifiers.shift != 0 { text += "\u{21E7}" }
        if modifiers & HotkeyModifiers.command != 0 { text += "\u{2318}" }
        return text + (keyName(for: keyCode) ?? "?")
    }

    /// Virtual key codes are positional, not character based — this is the
    /// standard US layout mapping Apple's `Events.h` documents.
    public static func keyName(for keyCode: UInt32) -> String? { keyNames[keyCode] }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "\u{21A9}", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "\u{21E5}", 49: "Space", 50: "`",
        51: "\u{232B}", 53: "esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        109: "F10", 111: "F12", 114: "Help", 115: "Home", 116: "Page Up", 117: "\u{2326}",
        118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
    ]
}
