import Foundation

/// Reads and writes AppSettings to a local JSON file.
public final class SettingsManager: Sendable {
    private let fileURL: URL

    public init(directory: URL? = nil) {
        let base = directory ?? SettingsManager.defaultDirectory
        self.fileURL = base.appendingPathComponent("settings.json")
    }

    private static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("YipYip", isDirectory: true)
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .default
        }
        let data = try Data(contentsOf: fileURL)
        let stored = try JSONDecoder().decode(AppSettings.self, from: data)
        let migrated = stored.migratingLegacyHotkey()
        // Write the upgrade back so the file stops advertising a hotkey the app
        // no longer registers.
        if migrated != stored { try? save(migrated) }
        return migrated
    }

    public func save(_ settings: AppSettings) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    public func exportSettings() throws -> Data {
        let settings = try load()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    public func importSettings(from data: Data) throws -> AppSettings {
        let settings = try JSONDecoder().decode(AppSettings.self, from: data).migratingLegacyHotkey()
        try save(settings)
        return settings
    }

    public var settingsFileURL: URL { fileURL }
}
