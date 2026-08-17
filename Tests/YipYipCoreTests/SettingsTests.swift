import Foundation
import Testing
@testable import YipYipCore

@Suite("Settings")
struct SettingsTests {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yipyip-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Default settings load when no file exists")
    func defaultSettings() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = SettingsManager(directory: dir)
        let settings = try manager.load()
        #expect(settings == .default)
    }

    @Test("Save and load round-trip")
    func saveLoadRoundTrip() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = SettingsManager(directory: dir)
        var settings = AppSettings.default
        settings.maxHistoryItems = 5000
        settings.theme = .dark
        settings.launchAtLogin = true

        try manager.save(settings)
        let loaded = try manager.load()

        #expect(loaded.maxHistoryItems == 5000)
        #expect(loaded.theme == .dark)
        #expect(loaded.launchAtLogin == true)
    }

    @Test("Export produces valid JSON")
    func exportJSON() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = SettingsManager(directory: dir)
        try manager.save(.default)

        let exported = try manager.exportSettings()
        let decoded = try JSONDecoder().decode(AppSettings.self, from: exported)
        #expect(decoded == .default)
    }

    @Test("Import overwrites existing settings")
    func importOverwrites() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = SettingsManager(directory: dir)
        try manager.save(.default)

        var newSettings = AppSettings.default
        newSettings.maxHistoryItems = 200
        newSettings.checkForUpdates = true
        let data = try JSONEncoder().encode(newSettings)

        let imported = try manager.importSettings(from: data)
        #expect(imported.maxHistoryItems == 200)
        #expect(imported.checkForUpdates == true)

        let reloaded = try manager.load()
        #expect(reloaded == imported)
    }

    @Test("Default hotkey is Command+Option+V")
    func defaultHotkey() {
        let settings = AppSettings.default
        #expect(settings.globalHotkeyKeyCode == 9)
        #expect(settings.globalHotkeyModifiers == HotkeyModifiers.command | HotkeyModifiers.option)
    }

    @Test("Legacy hotkey in a saved file is migrated on load")
    func legacyHotkeyMigrated() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        var legacy = AppSettings.default
        legacy.globalHotkeyModifiers = HotkeyModifiers.option | HotkeyModifiers.shift
        let manager = SettingsManager(directory: dir)
        try manager.save(legacy)

        let loaded = try manager.load()
        #expect(loaded.globalHotkeyModifiers == AppSettings.defaultHotkeyModifiers)

        // The migration is persisted, not just applied in memory.
        let onDisk = try JSONDecoder().decode(
            AppSettings.self,
            from: Data(contentsOf: manager.settingsFileURL)
        )
        #expect(onDisk.globalHotkeyModifiers == AppSettings.defaultHotkeyModifiers)
    }

    @Test("Non-legacy hotkey choices are left alone")
    func customHotkeyPreserved() {
        var custom = AppSettings.default
        custom.globalHotkeyKeyCode = 8 // C key
        custom.globalHotkeyModifiers = HotkeyModifiers.option | HotkeyModifiers.shift

        #expect(custom.migratingLegacyHotkey().globalHotkeyKeyCode == 8)
        #expect(custom.migratingLegacyHotkey().globalHotkeyModifiers
            == HotkeyModifiers.option | HotkeyModifiers.shift)
    }

    @Test("Sound effects default to on")
    func soundDefaults() {
        #expect(AppSettings.default.soundOnCopy)
        #expect(AppSettings.default.soundOnPaste)
    }

    @Test("Settings written before the sound keys existed still load")
    func decodesFileMissingNewerKeys() throws {
        let legacyJSON = """
        {
          "checkForUpdates" : false,
          "defaultExpirationDays" : 30,
          "globalHotkeyKeyCode" : 9,
          "globalHotkeyModifiers" : 2560,
          "launchAtLogin" : true,
          "maxHistoryItems" : 750,
          "theme" : "dark"
        }
        """

        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(legacyJSON.utf8))

        // Saved preferences survive; the unknown fields fall back to defaults.
        #expect(decoded.maxHistoryItems == 750)
        #expect(decoded.launchAtLogin)
        #expect(decoded.theme == .dark)
        #expect(decoded.soundOnCopy)
        #expect(decoded.soundOnPaste)
    }

    @Test("Max history items are clamped to valid range")
    func clampedRange() {
        let low = AppSettings(maxHistoryItems: 1)
        #expect(low.maxHistoryItems == 10)

        let high = AppSettings(maxHistoryItems: 100_000)
        #expect(high.maxHistoryItems == 50_000)
    }

    @Test("Expiration days are clamped to valid range")
    func expirationClamped() {
        let low = AppSettings(defaultExpirationDays: 0)
        #expect(low.defaultExpirationDays == 1)

        let high = AppSettings(defaultExpirationDays: 999)
        #expect(high.defaultExpirationDays == 365)
    }
}
