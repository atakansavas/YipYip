import Foundation
import Testing
@testable import YipYipCore

@Suite("Pinboard")
struct PinboardTests {

    @Test("Sanitize name removes special characters")
    func sanitizeName() {
        #expect(PinboardManager.sanitizeName("My Board!@#") == "My Board")
        #expect(PinboardManager.sanitizeName("  spaces  ") == "spaces")
        #expect(PinboardManager.sanitizeName("valid-name_123") == "valid-name_123")
    }

    @Test("Sanitize name truncates long names")
    func sanitizeTruncate() {
        let long = String(repeating: "a", count: 100)
        let sanitized = PinboardManager.sanitizeName(long)
        #expect(sanitized.count == 64)
    }

    @Test("Sanitize empty name returns empty")
    func sanitizeEmpty() {
        #expect(PinboardManager.sanitizeName("").isEmpty)
        #expect(PinboardManager.sanitizeName("!@#$").isEmpty)
    }
}
