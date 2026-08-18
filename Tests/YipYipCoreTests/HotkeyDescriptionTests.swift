import Foundation
import Testing
@testable import YipYipCore

@Suite("HotkeyDescription")
struct HotkeyDescriptionTests {
    @Test("Cocoa flags map onto Carbon masks")
    func cocoaToCarbon() {
        let flags = HotkeyDescription.CocoaFlag.command | HotkeyDescription.CocoaFlag.option
        #expect(HotkeyDescription.carbonModifiers(fromCocoa: flags)
            == HotkeyModifiers.command | HotkeyModifiers.option)

        // Cocoa flags carry extra bits (caps lock, device-dependent) that must
        // not leak into the Carbon mask.
        let noisy = flags | (1 << 16) | (1 << 8)
        #expect(HotkeyDescription.carbonModifiers(fromCocoa: noisy)
            == HotkeyModifiers.command | HotkeyModifiers.option)
    }

    @Test("The shipped default renders the way menus do")
    func defaultDisplay() {
        #expect(HotkeyDescription.display(
            keyCode: AppSettings.defaultHotkeyKeyCode,
            modifiers: AppSettings.defaultHotkeyModifiers
        ) == "⌥⌘V")
    }

    @Test("Modifier glyphs follow Apple's order")
    func glyphOrder() {
        let all = HotkeyModifiers.command | HotkeyModifiers.option
            | HotkeyModifiers.shift | HotkeyModifiers.control
        #expect(HotkeyDescription.display(keyCode: 49, modifiers: all) == "⌃⌥⇧⌘Space")
    }

    @Test("A shortcut without an anchoring modifier is rejected")
    func requiresAnchoringModifier() {
        #expect(!HotkeyDescription.isUsable(keyCode: 9, modifiers: 0))
        #expect(!HotkeyDescription.isUsable(keyCode: 9, modifiers: HotkeyModifiers.shift))
        #expect(HotkeyDescription.isUsable(keyCode: 9, modifiers: HotkeyModifiers.control))
        #expect(HotkeyDescription.isUsable(keyCode: 9, modifiers: AppSettings.defaultHotkeyModifiers))
    }

    @Test("Unknown key codes are rejected rather than shown as a number")
    func unknownKey() {
        #expect(HotkeyDescription.keyName(for: 200) == nil)
        #expect(!HotkeyDescription.isUsable(keyCode: 200, modifiers: HotkeyModifiers.command))
    }
}
