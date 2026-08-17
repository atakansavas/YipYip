import Foundation
import Testing
@testable import YipYipCore

@Suite("ClipboardStore")
struct ClipboardStoreTests {
    private func makeStore() throws -> (ClipboardStore, EncryptionManager) {
        let key = Data(repeating: 0xAA, count: 32)
        let enc = EncryptionManager(keyData: key)
        let db = try SQLiteDatabase(path: ":memory:")
        let store = try ClipboardStore(db: db, encryption: enc)
        return (store, enc)
    }

    private func makeSampleItem(
        enc: EncryptionManager,
        content: String = "hello",
        isPinned: Bool = false,
        pinboard: String? = nil,
        expiresAt: Date? = nil
    ) throws -> ClipboardItem {
        let data = Data(content.utf8)
        return ClipboardItem(
            encryptedContent: try enc.encrypt(data),
            contentType: .plainText,
            preview: content,
            expiresAt: expiresAt,
            isPinned: isPinned,
            pinboardName: pinboard,
            contentHash: EncryptionManager.contentHash(data)
        )
    }

    @Test("Re-copying an existing clip moves it back to the top")
    func touchBumpsToTop() throws {
        let (store, enc) = try makeStore()
        let old = Date().addingTimeInterval(-86_400)

        var first = try makeSampleItem(enc: enc, content: "5432615257")
        first = ClipboardItem(
            id: first.id,
            encryptedContent: first.encryptedContent,
            contentType: first.contentType,
            preview: first.preview,
            createdAt: old,
            sourceApp: "WhatsApp",
            contentHash: first.contentHash
        )
        try store.insert(first)
        try store.insert(try makeSampleItem(enc: enc, content: "something newer"))

        #expect(try store.recentItems(limit: 5).first?.preview == "something newer")

        try store.touch(id: first.id, expiresAt: nil, sourceApp: "Safari")

        let items = try store.recentItems(limit: 5)
        #expect(items.first?.preview == "5432615257")
        #expect(items.first?.sourceApp == "Safari")
        #expect(items.count == 2)  // promoted, not duplicated
    }

    @Test("Touch without a source app keeps the original one")
    func touchKeepsSourceApp() throws {
        let (store, enc) = try makeStore()
        let item = try makeSampleItem(enc: enc, content: "keep source")
        try store.insert(item)

        try store.touch(id: item.id, expiresAt: nil, sourceApp: nil)
        #expect(try store.recentItems(limit: 1).first?.sourceApp == item.sourceApp)
    }

    @Test("Insert and retrieve item")
    func insertAndRetrieve() throws {
        let (store, enc) = try makeStore()
        let item = try makeSampleItem(enc: enc, content: "test clip")
        try store.insert(item)

        let items = try store.recentItems(limit: 10)
        #expect(items.count == 1)
        #expect(items[0].preview == "test clip")
    }

    @Test("Search finds matching items")
    func searchFinds() throws {
        let (store, enc) = try makeStore()
        try store.insert(try makeSampleItem(enc: enc, content: "apple pie recipe"))
        try store.insert(try makeSampleItem(enc: enc, content: "banana bread"))
        try store.insert(try makeSampleItem(enc: enc, content: "cherry apple tart"))

        let results = try store.search(query: "apple")
        #expect(results.count == 2)
    }

    @Test("Search returns empty for no match")
    func searchEmpty() throws {
        let (store, enc) = try makeStore()
        try store.insert(try makeSampleItem(enc: enc, content: "only item"))

        let results = try store.search(query: "nonexistent")
        #expect(results.isEmpty)
    }

    @Test("Expired items excluded from recent")
    func expiredExcluded() throws {
        let (store, enc) = try makeStore()
        let pastDate = Date(timeIntervalSince1970: 0)
        try store.insert(try makeSampleItem(enc: enc, content: "old", expiresAt: pastDate))
        try store.insert(try makeSampleItem(enc: enc, content: "fresh"))

        let items = try store.recentItems()
        #expect(items.count == 1)
        #expect(items[0].preview == "fresh")
    }

    @Test("Delete expired removes correct items")
    func deleteExpired() throws {
        let (store, enc) = try makeStore()
        let pastDate = Date(timeIntervalSince1970: 0)
        try store.insert(try makeSampleItem(enc: enc, content: "expired", expiresAt: pastDate))
        try store.insert(try makeSampleItem(enc: enc, content: "current"))

        let removed = try store.deleteExpired()
        #expect(removed == 1)
        #expect(try store.itemCount() == 1)
    }

    @Test("Pinned items appear first")
    func pinnedFirst() throws {
        let (store, enc) = try makeStore()
        try store.insert(try makeSampleItem(enc: enc, content: "normal"))
        try store.insert(try makeSampleItem(enc: enc, content: "pinned", isPinned: true, pinboard: "Favorites"))

        let items = try store.recentItems()
        #expect(items.count == 2)
        #expect(items[0].isPinned == true)
        #expect(items[0].preview == "pinned")
    }

    @Test("Enforce limit keeps most recent")
    func enforceLimit() throws {
        let (store, enc) = try makeStore()
        for i in 0..<10 {
            try store.insert(try makeSampleItem(enc: enc, content: "item \(i)"))
        }
        try store.enforceLimit(5)
        #expect(try store.itemCount() == 5)
    }

    @Test("Delete single item")
    func deleteSingle() throws {
        let (store, enc) = try makeStore()
        let item = try makeSampleItem(enc: enc, content: "to delete")
        try store.insert(item)
        try store.delete(id: item.id)
        #expect(try store.itemCount() == 0)
    }

    @Test("Delete all clears everything")
    func deleteAll() throws {
        let (store, enc) = try makeStore()
        for i in 0..<5 {
            try store.insert(try makeSampleItem(enc: enc, content: "item \(i)"))
        }
        try store.deleteAll()
        #expect(try store.itemCount() == 0)
    }

    @Test("Decrypt content round-trips through store")
    func decryptContent() throws {
        let (store, enc) = try makeStore()
        let item = try makeSampleItem(enc: enc, content: "secret message")
        try store.insert(item)

        let retrieved = try store.recentItems().first!
        let decrypted = try store.decryptContent(of: retrieved)
        #expect(String(data: decrypted, encoding: .utf8) == "secret message")
    }

    @Test("Pinboard listing")
    func pinboardListing() throws {
        let (store, enc) = try makeStore()
        try store.insert(try makeSampleItem(enc: enc, content: "a", isPinned: true, pinboard: "Work"))
        try store.insert(try makeSampleItem(enc: enc, content: "b", isPinned: true, pinboard: "Personal"))
        try store.insert(try makeSampleItem(enc: enc, content: "c", isPinned: true, pinboard: "Work"))

        let pinboards = try store.pinboards()
        #expect(pinboards.count == 2)
        #expect(pinboards.contains("Work"))
        #expect(pinboards.contains("Personal"))
    }

    @Test("Item by hash finds correct item")
    func itemByHash() throws {
        let (store, enc) = try makeStore()
        let content = "unique content"
        let hash = EncryptionManager.contentHash(Data(content.utf8))
        try store.insert(try makeSampleItem(enc: enc, content: content))

        let found = try store.item(byHash: hash)
        #expect(found != nil)
        #expect(found?.preview == content)
    }
}
