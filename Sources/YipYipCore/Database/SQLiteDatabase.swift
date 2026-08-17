import Foundation
import SQLite3

/// Thin wrapper around SQLite C API providing safe prepared statements.
public final class SQLiteDatabase: @unchecked Sendable {
    private let db: OpaquePointer
    private let queue = DispatchQueue(label: "com.benatakan.yipyip.sqlite", qos: .userInitiated)

    public init(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(path, &handle, flags, nil)
        guard status == SQLITE_OK, let db = handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown"
            sqlite3_close(handle)
            throw SQLiteError.openFailed(msg)
        }
        self.db = db
        sqlite3_busy_timeout(db, 5000)
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
    }

    deinit {
        sqlite3_close(db)
    }

    /// Execute a statement that returns no rows.
    @discardableResult
    public func execute(_ sql: String, params: [SQLiteValue] = []) throws -> Int {
        try queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            try bind(stmt: stmt!, params: params)
            let result = sqlite3_step(stmt)
            guard result == SQLITE_DONE || result == SQLITE_ROW else {
                throw SQLiteError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
            return Int(sqlite3_changes(db))
        }
    }

    /// Execute a query and map each row.
    public func query<T>(_ sql: String, params: [SQLiteValue] = [], mapper: (OpaquePointer) -> T) throws -> [T] {
        try queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            try bind(stmt: stmt!, params: params)
            var rows: [T] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(mapper(stmt!))
            }
            return rows
        }
    }

    private func bind(stmt: OpaquePointer, params: [SQLiteValue]) throws {
        for (index, param) in params.enumerated() {
            let pos = Int32(index + 1)
            let status: Int32
            switch param {
            case .text(let s):
                status = sqlite3_bind_text(stmt, pos, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .int(let i):
                status = sqlite3_bind_int64(stmt, pos, Int64(i))
            case .double(let d):
                status = sqlite3_bind_double(stmt, pos, d)
            case .blob(let data):
                status = data.withUnsafeBytes { buf in
                    sqlite3_bind_blob(stmt, pos, buf.baseAddress, Int32(data.count),
                                      unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case .null:
                status = sqlite3_bind_null(stmt, pos)
            }
            guard status == SQLITE_OK else {
                throw SQLiteError.bindFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
}

public enum SQLiteValue: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null
}

public enum SQLiteError: Error, LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "SQLite open failed: \(m)"
        case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
        case .stepFailed(let m): return "SQLite step failed: \(m)"
        case .bindFailed(let m): return "SQLite bind failed: \(m)"
        }
    }
}
