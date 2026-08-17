import Foundation
import Testing
@testable import YipYipCore

@Suite("ClipboardItem")
struct ClipboardItemTests {

    @Test("Preview is truncated to 500 characters")
    func previewTruncation() {
        let longString = String(repeating: "a", count: 1000)
        let item = ClipboardItem(
            encryptedContent: Data(),
            contentType: .plainText,
            preview: longString,
            contentHash: "test"
        )
        #expect(item.preview.count == 500)
    }

    @Test("isExpired returns true for past dates")
    func isExpiredTrue() {
        let item = ClipboardItem(
            encryptedContent: Data(),
            contentType: .plainText,
            preview: "test",
            expiresAt: Date(timeIntervalSince1970: 0),
            contentHash: "test"
        )
        #expect(item.isExpired == true)
    }

    @Test("isExpired returns false for future dates")
    func isExpiredFalse() {
        let item = ClipboardItem(
            encryptedContent: Data(),
            contentType: .plainText,
            preview: "test",
            expiresAt: Date.distantFuture,
            contentHash: "test"
        )
        #expect(item.isExpired == false)
    }

    @Test("isExpired returns false when no expiry set")
    func isExpiredNil() {
        let item = ClipboardItem(
            encryptedContent: Data(),
            contentType: .plainText,
            preview: "test",
            expiresAt: nil,
            contentHash: "test"
        )
        #expect(item.isExpired == false)
    }
}
