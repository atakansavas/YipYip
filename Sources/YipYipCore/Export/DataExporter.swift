import Foundation

/// Exports and imports clipboard history as JSON for backup or migration.
public struct DataExporter: Sendable {

    public struct ExportableItem: Codable, Sendable {
        public let id: String
        public let contentType: String
        public let preview: String
        public let createdAt: Date
        public let expiresAt: Date?
        public let isPinned: Bool
        public let pinboardName: String?
        public let sourceApp: String?
    }

    /// Export metadata only (no encrypted content for safety).
    public static func exportMetadata(items: [ClipboardItem]) throws -> Data {
        let exportable = items.map { item in
            ExportableItem(
                id: item.id.uuidString,
                contentType: item.contentType.rawValue,
                preview: item.preview,
                createdAt: item.createdAt,
                expiresAt: item.expiresAt,
                isPinned: item.isPinned,
                pinboardName: item.pinboardName,
                sourceApp: item.sourceApp
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportable)
    }

    /// Export full items including encrypted content (for local backup only).
    public static func exportFull(items: [ClipboardItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(items)
    }

    /// Import items from a full backup.
    public static func importFull(data: Data) throws -> [ClipboardItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ClipboardItem].self, from: data)
    }

    /// Generate a safe filename with timestamp.
    public static func safeFilename(prefix: String = "yipyip-export") -> String {
        let sanitized = prefix
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "\(sanitized)_\(timestamp).json"
    }

    /// Generate a diagnostics report for troubleshooting.
    public static func diagnosticsReport(
        itemCount: Int,
        dbPath: String,
        settingsPath: String,
        accessibilityGranted: Bool,
        appVersion: String = AppInfo.version
    ) -> String {
        """
        YipYip Diagnostics Report
        ============================
        Version: \(appVersion)
        Date: \(ISO8601DateFormatter().string(from: Date()))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility (needed to paste): \(accessibilityGranted ? "granted" : "NOT GRANTED")
        Items in database: \(itemCount)
        Database path: \(dbPath)
        Settings path: \(settingsPath)
        Disk space available: \(diskSpaceFormatted())
        """
    }

    private static func diskSpaceFormatted() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: home.path),
              let free = attrs[.systemFreeSize] as? Int64
        else {
            return "Unknown"
        }
        let gb = Double(free) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}
