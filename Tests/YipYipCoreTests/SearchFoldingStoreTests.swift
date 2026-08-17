import Foundation
import SQLite3
import Testing
@testable import YipYipCore

@Suite("Search folding in the store")
struct SearchFoldingStoreTests {
    private func makeStore(path: String = ":memory:") throws -> (ClipboardStore, EncryptionManager, SQLiteDatabase) {
        let enc = EncryptionManager(keyData: Data(repeating: 0xAA, count: 32))
        let db = try SQLiteDatabase(path: path)
        return (try ClipboardStore(db: db, encryption: enc), enc, db)
    }

    private func item(_ preview: String, enc: EncryptionManager) throws -> ClipboardItem {
        let data = Data(preview.utf8)
        return ClipboardItem(
            encryptedContent: try enc.encrypt(data),
            contentType: .plainText,
            preview: preview,
            contentHash: EncryptionManager.contentHash(data)
        )
    }

    @Test("ASCII query finds the Turkish spelling")
    func asciiFindsTurkish() throws {
        let (store, enc, _) = try makeStore()
        try store.insert(try item("inşallah yarın görüşürüz", enc: enc))

        #expect(try store.search(query: "insallah").count == 1)
        #expect(try store.search(query: "gorusuruz").count == 1)
        #expect(try store.search(query: "YARIN").count == 1)
    }

    @Test("Turkish query finds the ASCII spelling")
    func turkishFindsASCII() throws {
        let (store, enc, _) = try makeStore()
        try store.insert(try item("insallah gorusuruz", enc: enc))

        #expect(try store.search(query: "inşallah").count == 1)
        #expect(try store.search(query: "GÖRÜŞÜRÜZ").count == 1)
    }

    @Test("Dotted and dotless i are interchangeable")
    func dottedI() throws {
        let (store, enc, _) = try makeStore()
        try store.insert(try item("İstanbul ışıkları", enc: enc))

        #expect(try store.search(query: "istanbul").count == 1)
        #expect(try store.search(query: "isiklari").count == 1)
        #expect(try store.search(query: "IŞIKLARI").count == 1)
    }

    @Test("Unrelated queries still miss")
    func noFalsePositives() throws {
        let (store, enc, _) = try makeStore()
        try store.insert(try item("inşallah", enc: enc))

        #expect(try store.search(query: "maşallah").isEmpty)
        #expect(try store.search(query: "xyz").isEmpty)
    }

    @Test("LIKE wildcards in a query are still escaped")
    func wildcardsEscaped() throws {
        let (store, enc, _) = try makeStore()
        try store.insert(try item("şeker", enc: enc))

        #expect(try store.search(query: "%").isEmpty)
        #expect(try store.search(query: "_eker").isEmpty)
    }

    @Test("Rows written before folding existed become searchable")
    func migratesExistingDatabase() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("yipyip-migrate-\(UUID().uuidString).db").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        // A database in the pre-folding shape, with a row already in it.
        let legacy = try SQLiteDatabase(path: path)
        try legacy.execute("""
            CREATE TABLE clipboard_items (
                id TEXT PRIMARY KEY,
                encrypted_content BLOB NOT NULL,
                content_type TEXT NOT NULL,
                preview TEXT NOT NULL,
                created_at REAL NOT NULL,
                expires_at REAL,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                pinboard_name TEXT,
                source_app TEXT,
                content_hash TEXT NOT NULL
            )
            """)
        try legacy.execute("""
            INSERT INTO clipboard_items
            (id, encrypted_content, content_type, preview, created_at, content_hash)
            VALUES (?, ?, 'plainText', ?, ?, 'legacy-hash')
            """, params: [
                .text(UUID().uuidString),
                .blob(Data([0x01])),
                .text("eski kayıt: İzmir güneşli"),
                .double(Date().timeIntervalSince1970),
            ])

        let enc = EncryptionManager(keyData: Data(repeating: 0xAA, count: 32))
        let store = try ClipboardStore(db: legacy, encryption: enc)

        #expect(try store.search(query: "izmir").count == 1)
        #expect(try store.search(query: "gunesli").count == 1)
    }
}
