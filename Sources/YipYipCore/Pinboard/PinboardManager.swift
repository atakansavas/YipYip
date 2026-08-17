import Foundation

/// High-level helpers for managing pinboards (named collections of pinned items).
public struct PinboardManager: Sendable {
    private let store: ClipboardStore

    public init(store: ClipboardStore) {
        self.store = store
    }

    /// List all pinboard names.
    public func listPinboards() throws -> [String] {
        try store.pinboards()
    }

    /// Pin an item to a named pinboard, creating it implicitly.
    public func pin(itemId: UUID, to pinboard: String) throws {
        let sanitized = Self.sanitizeName(pinboard)
        guard !sanitized.isEmpty else { return }
        try store.togglePin(id: itemId, pinboardName: sanitized)
    }

    /// Unpin an item (toggle off).
    public func unpin(itemId: UUID) throws {
        try store.togglePin(id: itemId, pinboardName: nil)
    }

    /// Get all items in a pinboard.
    public func items(in pinboard: String) throws -> [ClipboardItem] {
        try store.pinnedItems(pinboard: pinboard)
    }

    /// Sanitize a pinboard name for safe use as part of filenames or labels.
    public static func sanitizeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: " -_"))
        let cleaned = name.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
            .trimmingCharacters(in: .whitespaces)
        return String(result.prefix(64))
    }
}
