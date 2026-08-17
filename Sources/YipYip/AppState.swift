import AppKit
import YipYipCore
import Foundation

enum HistoryTab: String, CaseIterable, Sendable {
    case all = "All"
    case pinned = "Pinned"
}

@MainActor
@Observable
final class AppState {
    var items: [ClipboardItem] = []
    var searchQuery: String = ""
    var settings: AppSettings
    var errorMessage: String?
    var isLoading: Bool = false
    var selectedIndex: Int = 0
    var activeTab: HistoryTab = .all
    var toastMessage: String?
    var showPinSheet: Bool = false
    var pinTargetItem: ClipboardItem?
    var availablePinboards: [String] = []

    // Ignored by observation: these are render caches, and mutating them while a
    // row is drawing would invalidate the very view that asked for them.
    @ObservationIgnored private var thumbnailCache: [UUID: NSImage] = [:]
    @ObservationIgnored private var fileIconCache: [UUID: NSImage] = [:]
    @ObservationIgnored private var fileURLCache: [UUID: [URL]] = [:]
    /// Hash of the last clip YipYip itself put on the pasteboard.
    @ObservationIgnored private var lastWrittenHash: String?

    let store: ClipboardStore
    let settingsManager: SettingsManager
    let encryption: EncryptionManager
    let dbPath: String

    init() throws {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("YipYip", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let path = dir.appendingPathComponent("yipyip.db").path
        self.dbPath = path

        let keychain = KeychainManager()
        let enc = try EncryptionManager(keychainManager: keychain)
        self.encryption = enc

        let db = try SQLiteDatabase(path: path)
        self.store = try ClipboardStore(db: db, encryption: enc)

        self.settingsManager = SettingsManager(directory: dir)
        self.settings = (try? settingsManager.load()) ?? .default

        refreshItems()
        refreshPinboards()
    }

    func refreshItems() {
        isLoading = true
        errorMessage = nil
        do {
            switch activeTab {
            case .all:
                if searchQuery.isEmpty {
                    items = try store.recentItems(limit: 100)
                } else {
                    items = try store.search(query: searchQuery, limit: 100)
                }
            case .pinned:
                if searchQuery.isEmpty {
                    items = try store.pinnedItems()
                } else {
                    items = try store.search(query: searchQuery, limit: 100).filter(\.isPinned)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
        isLoading = false

        if selectedIndex >= items.count {
            selectedIndex = max(0, items.count - 1)
        }
    }

    func refreshPinboards() {
        availablePinboards = (try? store.pinboards()) ?? []
    }

    /// Records a captured clip. Returns true when the user should be told about
    /// it — that is, for anything they copied, whether it is new or a clip being
    /// promoted back to the top. Returns false for our own pasteboard writes and
    /// for failures.
    @discardableResult
    func addItem(_ capture: ClipboardCapture, sourceApp: String?) -> Bool {
        do {
            let hash = EncryptionManager.contentHash(capture.data)
            let expiresAt = Calendar.current.date(
                byAdding: .day, value: settings.defaultExpirationDays, to: Date()
            )

            if let existing = try store.item(byHash: hash) {
                // Pasting from YipYip puts the clip back on the pasteboard;
                // that echo should reorder history silently, not chime again —
                // and it must not relabel the clip as coming from YipYip.
                let isOwnWrite = hash == lastWrittenHash
                lastWrittenHash = nil

                try store.touch(
                    id: existing.id,
                    expiresAt: expiresAt,
                    sourceApp: isOwnWrite ? nil : sourceApp
                )
                refreshItems()
                return !isOwnWrite
            }

            let encrypted = try encryption.encrypt(capture.data)

            let item = ClipboardItem(
                encryptedContent: encrypted,
                contentType: capture.contentType,
                preview: capture.preview,
                expiresAt: expiresAt,
                sourceApp: sourceApp,
                contentHash: hash
            )
            try store.insert(item)
            try store.enforceLimit(settings.maxHistoryItems)
            refreshItems()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Puts the item back on the pasteboard in its original form. Returns false
    /// when it could not be read.
    @discardableResult
    func copyToClipboard(item: ClipboardItem, showToast toast: Bool = true) -> Bool {
        do {
            let data = try store.decryptContent(of: item)
            guard ClipboardCapture.restore(
                data: data,
                contentType: item.contentType,
                to: NSPasteboard.general
            ) else { return false }

            lastWrittenHash = item.contentHash
            if toast { showToast("Copied") }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Attachments

    /// Decoded image for an image item, downscaled for the list. Cached because
    /// SwiftUI asks for it on every row redraw.
    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard item.contentType == .image else { return nil }
        if let cached = thumbnailCache[item.id] { return cached }

        guard let data = try? store.decryptContent(of: item),
              let full = NSImage(data: data)
        else { return nil }

        let thumbnail = Self.downscaled(full, fitting: NSSize(width: 96, height: 72))
        thumbnailCache[item.id] = thumbnail
        return thumbnail
    }

    /// Finder icon for a file item, or nil when the file no longer exists.
    func fileIcon(for item: ClipboardItem) -> NSImage? {
        guard item.contentType == .fileReference else { return nil }
        if let cached = fileIconCache[item.id] { return cached }

        guard let url = fileURLs(of: item).first else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        fileIconCache[item.id] = icon
        return icon
    }

    func fileURLs(of item: ClipboardItem) -> [URL] {
        guard item.contentType == .fileReference else { return [] }
        if let cached = fileURLCache[item.id] { return cached }

        guard let data = try? store.decryptContent(of: item) else { return [] }
        let urls = ClipboardCapture.fileURLs(from: data)
        // Cached so list redraws do not decrypt once per visible row per frame.
        fileURLCache[item.id] = urls
        return urls
    }

    /// True when every referenced file is still on disk.
    func filesExist(for item: ClipboardItem) -> Bool {
        let urls = fileURLs(of: item)
        guard !urls.isEmpty else { return false }
        return urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    func revealInFinder(_ item: ClipboardItem) {
        let urls = fileURLs(of: item)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private static func downscaled(_ image: NSImage, fitting bounds: NSSize) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let scale = min(bounds.width / size.width, bounds.height / size.height, 1)
        let target = NSSize(width: max(1, size.width * scale), height: max(1, size.height * scale))

        let thumbnail = NSImage(size: target)
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target))
        thumbnail.unlockFocus()
        return thumbnail
    }

    func deleteItem(_ item: ClipboardItem) {
        do {
            try store.delete(id: item.id)
            thumbnailCache[item.id] = nil
            fileIconCache[item.id] = nil
            fileURLCache[item.id] = nil
            showToast("Deleted")
            refreshItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePin(_ item: ClipboardItem, pinboard: String? = nil) {
        do {
            try store.togglePin(id: item.id, pinboardName: pinboard)
            let wasPinned = item.isPinned
            showToast(wasPinned ? "Unpinned" : "Pinned")
            refreshItems()
            refreshPinboards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginPinning(item: ClipboardItem) {
        pinTargetItem = item
        refreshPinboards()
        showPinSheet = true
    }

    func cleanupExpired() {
        do {
            let removed = try store.deleteExpired()
            if removed > 0 { refreshItems() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSettings() {
        do {
            try settingsManager.save(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        guard items.indices.contains(newIndex) else { return }
        selectedIndex = newIndex
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    var selectedItem: ClipboardItem? {
        items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }
}
