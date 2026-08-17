import Foundation
import SQLite3

/// Persists and queries ClipboardItem records in SQLite.
public final class ClipboardStore: @unchecked Sendable {
    private let db: SQLiteDatabase
    private let encryption: EncryptionManager

    public init(db: SQLiteDatabase, encryption: EncryptionManager) throws {
        self.db = db
        self.encryption = encryption
        try createTables()
    }

    private func createTables() throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY,
                encrypted_content BLOB NOT NULL,
                content_type TEXT NOT NULL,
                preview TEXT NOT NULL,
                created_at REAL NOT NULL,
                expires_at REAL,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                pinboard_name TEXT,
                source_app TEXT,
                content_hash TEXT NOT NULL,
                preview_folded TEXT NOT NULL DEFAULT ''
            )
            """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_created ON clipboard_items(created_at DESC)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_hash ON clipboard_items(content_hash)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_pinboard ON clipboard_items(pinboard_name)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_preview ON clipboard_items(preview)")
        try addFoldedPreviewColumnIfNeeded()
    }

    /// Databases written before search folding existed have no `preview_folded`;
    /// add it and fill it in so old clips are searchable the same way as new ones.
    private func addFoldedPreviewColumnIfNeeded() throws {
        let columns = try db.query("PRAGMA table_info(clipboard_items)", mapper: { stmt in
            String(cString: sqlite3_column_text(stmt, 1))
        })
        if !columns.contains("preview_folded") {
            try db.execute("ALTER TABLE clipboard_items ADD COLUMN preview_folded TEXT NOT NULL DEFAULT ''")
        }

        try backfillFoldedPreviews()
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_folded ON clipboard_items(preview_folded)")
    }

    private func backfillFoldedPreviews() throws {
        let pending = try db.query("""
            SELECT id, preview FROM clipboard_items WHERE preview_folded = '' AND preview <> ''
            """, mapper: { stmt in
            (id: String(cString: sqlite3_column_text(stmt, 0)),
             preview: String(cString: sqlite3_column_text(stmt, 1)))
        })

        for row in pending {
            try db.execute("UPDATE clipboard_items SET preview_folded = ? WHERE id = ?",
                           params: [.text(SearchText.fold(row.preview)), .text(row.id)])
        }
    }

    // MARK: - Insert

    public func insert(_ item: ClipboardItem) throws {
        try db.execute("""
            INSERT OR REPLACE INTO clipboard_items
            (id, encrypted_content, content_type, preview, created_at, expires_at,
             is_pinned, pinboard_name, source_app, content_hash, preview_folded)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, params: [
                .text(item.id.uuidString),
                .blob(item.encryptedContent),
                .text(item.contentType.rawValue),
                .text(item.preview),
                .double(item.createdAt.timeIntervalSince1970),
                item.expiresAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                .int(item.isPinned ? 1 : 0),
                item.pinboardName.map { .text($0) } ?? .null,
                item.sourceApp.map { .text($0) } ?? .null,
                .text(item.contentHash),
                .text(SearchText.fold(item.preview)),
            ])
    }

    // MARK: - Query

    /// Matches on the folded preview, so the query finds clips regardless of
    /// diacritics or case ("insallah" finds "inşallah").
    public func search(query: String, limit: Int = 50) throws -> [ClipboardItem] {
        let sanitized = SearchText.fold(query)
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return try db.query("""
            SELECT * FROM clipboard_items
            WHERE preview_folded LIKE ? ESCAPE '\\'
              AND (expires_at IS NULL OR expires_at > ?)
            ORDER BY is_pinned DESC, created_at DESC
            LIMIT ?
            """, params: [
                .text("%\(sanitized)%"),
                .double(Date().timeIntervalSince1970),
                .int(limit),
            ], mapper: mapRow)
    }

    public func recentItems(limit: Int = 50) throws -> [ClipboardItem] {
        try db.query("""
            SELECT * FROM clipboard_items
            WHERE (expires_at IS NULL OR expires_at > ?)
            ORDER BY is_pinned DESC, created_at DESC
            LIMIT ?
            """, params: [
                .double(Date().timeIntervalSince1970),
                .int(limit),
            ], mapper: mapRow)
    }

    public func item(byHash hash: String) throws -> ClipboardItem? {
        try db.query("""
            SELECT * FROM clipboard_items WHERE content_hash = ? LIMIT 1
            """, params: [.text(hash)], mapper: mapRow).first
    }

    public func pinnedItems(pinboard: String? = nil) throws -> [ClipboardItem] {
        if let pinboard {
            return try db.query("""
                SELECT * FROM clipboard_items
                WHERE is_pinned = 1 AND pinboard_name = ?
                ORDER BY created_at DESC
                """, params: [.text(pinboard)], mapper: mapRow)
        }
        return try db.query("""
            SELECT * FROM clipboard_items
            WHERE is_pinned = 1
            ORDER BY created_at DESC
            """, mapper: mapRow)
    }

    public func pinboards() throws -> [String] {
        try db.query("""
            SELECT DISTINCT pinboard_name FROM clipboard_items
            WHERE pinboard_name IS NOT NULL
            ORDER BY pinboard_name
            """, mapper: { stmt in
            String(cString: sqlite3_column_text(stmt, 0))
        })
    }

    // MARK: - Update

    /// Moves an existing clip back to the top of the history and restarts its
    /// expiry. Re-copying something must surface it — leaving it at its
    /// first-seen timestamp makes the copy look like it never registered.
    public func touch(id: UUID, at date: Date = Date(), expiresAt: Date?, sourceApp: String?) throws {
        try db.execute("""
            UPDATE clipboard_items
            SET created_at = ?, expires_at = ?, source_app = COALESCE(?, source_app)
            WHERE id = ?
            """, params: [
                .double(date.timeIntervalSince1970),
                expiresAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                sourceApp.map { .text($0) } ?? .null,
                .text(id.uuidString),
            ])
    }

    public func togglePin(id: UUID, pinboardName: String? = nil) throws {
        try db.execute("""
            UPDATE clipboard_items
            SET is_pinned = CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END,
                pinboard_name = CASE WHEN is_pinned = 1 THEN NULL ELSE ? END
            WHERE id = ?
            """, params: [
                pinboardName.map { .text($0) } ?? .null,
                .text(id.uuidString),
            ])
    }

    // MARK: - Delete

    public func delete(id: UUID) throws {
        try db.execute("DELETE FROM clipboard_items WHERE id = ?",
                       params: [.text(id.uuidString)])
    }

    public func deleteExpired() throws -> Int {
        try db.execute("""
            DELETE FROM clipboard_items
            WHERE expires_at IS NOT NULL AND expires_at <= ? AND is_pinned = 0
            """, params: [.double(Date().timeIntervalSince1970)])
    }

    public func deleteAll() throws {
        try db.execute("DELETE FROM clipboard_items")
    }

    public func enforceLimit(_ maxItems: Int) throws {
        try db.execute("""
            DELETE FROM clipboard_items
            WHERE id NOT IN (
                SELECT id FROM clipboard_items
                ORDER BY is_pinned DESC, created_at DESC
                LIMIT ?
            )
            """, params: [.int(maxItems)])
    }

    public func itemCount() throws -> Int {
        let rows = try db.query("SELECT COUNT(*) FROM clipboard_items", mapper: { stmt in
            Int(sqlite3_column_int64(stmt, 0))
        })
        return rows.first ?? 0
    }

    // MARK: - Decrypt helper

    public func decryptContent(of item: ClipboardItem) throws -> Data {
        try encryption.decrypt(item.encryptedContent)
    }

    // MARK: - Row mapper

    private func mapRow(_ stmt: OpaquePointer) -> ClipboardItem {
        let idStr = String(cString: sqlite3_column_text(stmt, 0))
        let blobPtr = sqlite3_column_blob(stmt, 1)
        let blobLen = sqlite3_column_bytes(stmt, 1)
        let encrypted = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) } ?? Data()
        let typeStr = String(cString: sqlite3_column_text(stmt, 2))
        let preview = String(cString: sqlite3_column_text(stmt, 3))
        let created = sqlite3_column_double(stmt, 4)
        let expiresRaw = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
        let pinned = sqlite3_column_int(stmt, 6) != 0
        let pinboard = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 7))
        let source = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 8))
        let hash = String(cString: sqlite3_column_text(stmt, 9))

        return ClipboardItem(
            id: UUID(uuidString: idStr) ?? UUID(),
            encryptedContent: encrypted,
            contentType: ClipboardItem.ContentType(rawValue: typeStr) ?? .plainText,
            preview: preview,
            createdAt: Date(timeIntervalSince1970: created),
            expiresAt: expiresRaw.map { Date(timeIntervalSince1970: $0) },
            isPinned: pinned,
            pinboardName: pinboard,
            sourceApp: source,
            contentHash: hash
        )
    }
}
