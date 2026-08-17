import Foundation

/// Represents a single clipboard history entry.
public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let encryptedContent: Data
    public let contentType: ContentType
    public let preview: String
    public let createdAt: Date
    public let expiresAt: Date?
    public var isPinned: Bool
    public var pinboardName: String?
    public let sourceApp: String?
    public let contentHash: String

    public enum ContentType: String, Codable, Sendable, CaseIterable {
        case plainText
        case richText
        case image
        case url
        case fileReference
    }

    public init(
        id: UUID = UUID(),
        encryptedContent: Data,
        contentType: ContentType,
        preview: String,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        isPinned: Bool = false,
        pinboardName: String? = nil,
        sourceApp: String? = nil,
        contentHash: String
    ) {
        self.id = id
        self.encryptedContent = encryptedContent
        self.contentType = contentType
        self.preview = String(preview.prefix(500))
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isPinned = isPinned
        self.pinboardName = pinboardName
        self.sourceApp = sourceApp
        self.contentHash = contentHash
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }
}
