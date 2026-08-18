import Foundation

/// Carbon modifier masks used by the global hotkey registration.
public enum HotkeyModifiers {
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000
}

/// All user-configurable settings, stored locally as JSON.
public struct AppSettings: Codable, Sendable, Equatable {
    public var maxHistoryItems: Int
    public var defaultExpirationDays: Int
    public var globalHotkeyKeyCode: UInt32
    public var globalHotkeyModifiers: UInt32
    public var launchAtLogin: Bool
    public var checkForUpdates: Bool
    public var theme: Theme
    /// Plays a short chime when a new clip is captured.
    public var soundOnCopy: Bool
    /// Plays a short chime when an item is pasted from the search panel.
    public var soundOnPaste: Bool
    /// Skips clips an app marked as a password or as transient.
    public var ignoreConcealedClips: Bool
    /// Set once the welcome window has been dismissed.
    public var hasCompletedOnboarding: Bool

    public enum Theme: String, Codable, Sendable, CaseIterable {
        case light
        case dark
        case system
    }

    /// V key.
    public static let defaultHotkeyKeyCode: UInt32 = 9
    /// Command + Option.
    public static let defaultHotkeyModifiers: UInt32 = HotkeyModifiers.command | HotkeyModifiers.option

    /// Combos shipped by earlier versions, upgraded to the current default on load.
    static let legacyHotkeyModifiers: [UInt32] = [
        HotkeyModifiers.option | HotkeyModifiers.shift,
        HotkeyModifiers.command | HotkeyModifiers.shift,
    ]

    public static let `default` = AppSettings(
        maxHistoryItems: 1000,
        defaultExpirationDays: 30,
        globalHotkeyKeyCode: defaultHotkeyKeyCode,
        globalHotkeyModifiers: defaultHotkeyModifiers,
        launchAtLogin: false,
        checkForUpdates: false,
        theme: .system,
        soundOnCopy: true,
        soundOnPaste: true,
        ignoreConcealedClips: true,
        hasCompletedOnboarding: false
    )

    public init(
        maxHistoryItems: Int = 1000,
        defaultExpirationDays: Int = 30,
        globalHotkeyKeyCode: UInt32 = AppSettings.defaultHotkeyKeyCode,
        globalHotkeyModifiers: UInt32 = AppSettings.defaultHotkeyModifiers,
        launchAtLogin: Bool = false,
        checkForUpdates: Bool = false,
        theme: Theme = .system,
        soundOnCopy: Bool = true,
        soundOnPaste: Bool = true,
        ignoreConcealedClips: Bool = true,
        hasCompletedOnboarding: Bool = false
    ) {
        self.maxHistoryItems = max(10, min(maxHistoryItems, 50_000))
        self.defaultExpirationDays = max(1, min(defaultExpirationDays, 365))
        self.globalHotkeyKeyCode = globalHotkeyKeyCode
        self.globalHotkeyModifiers = globalHotkeyModifiers
        self.launchAtLogin = launchAtLogin
        self.checkForUpdates = checkForUpdates
        self.theme = theme
        self.soundOnCopy = soundOnCopy
        self.soundOnPaste = soundOnPaste
        self.ignoreConcealedClips = ignoreConcealedClips
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    /// Decoded key by key so a settings file written before a field existed
    /// still loads — the synthesized initializer would throw on the missing key
    /// and drop every other saved preference with it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        self.init(
            maxHistoryItems: try container.decodeIfPresent(Int.self, forKey: .maxHistoryItems)
                ?? fallback.maxHistoryItems,
            defaultExpirationDays: try container.decodeIfPresent(Int.self, forKey: .defaultExpirationDays)
                ?? fallback.defaultExpirationDays,
            globalHotkeyKeyCode: try container.decodeIfPresent(UInt32.self, forKey: .globalHotkeyKeyCode)
                ?? fallback.globalHotkeyKeyCode,
            globalHotkeyModifiers: try container.decodeIfPresent(UInt32.self, forKey: .globalHotkeyModifiers)
                ?? fallback.globalHotkeyModifiers,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin)
                ?? fallback.launchAtLogin,
            checkForUpdates: try container.decodeIfPresent(Bool.self, forKey: .checkForUpdates)
                ?? fallback.checkForUpdates,
            theme: try container.decodeIfPresent(Theme.self, forKey: .theme) ?? fallback.theme,
            soundOnCopy: try container.decodeIfPresent(Bool.self, forKey: .soundOnCopy)
                ?? fallback.soundOnCopy,
            soundOnPaste: try container.decodeIfPresent(Bool.self, forKey: .soundOnPaste)
                ?? fallback.soundOnPaste,
            ignoreConcealedClips: try container.decodeIfPresent(Bool.self, forKey: .ignoreConcealedClips)
                ?? fallback.ignoreConcealedClips,
            hasCompletedOnboarding: try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
                ?? fallback.hasCompletedOnboarding
        )
    }

    /// Settings files written by older builds still carry the previous hotkey.
    /// Since the combo is not user-editable yet, move those over to the current
    /// default instead of leaving them on a shortcut we no longer document.
    public func migratingLegacyHotkey() -> AppSettings {
        guard globalHotkeyKeyCode == AppSettings.defaultHotkeyKeyCode,
              AppSettings.legacyHotkeyModifiers.contains(globalHotkeyModifiers)
        else { return self }

        var updated = self
        updated.globalHotkeyModifiers = AppSettings.defaultHotkeyModifiers
        return updated
    }
}
