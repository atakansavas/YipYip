import Foundation
import Testing
@testable import YipYipCore

@Suite("Encryption")
struct EncryptionTests {

    @Test("Round-trip encrypt and decrypt returns original data")
    func roundTrip() throws {
        let key = Data(repeating: 0xAB, count: 32)
        let manager = EncryptionManager(keyData: key)

        let original = Data("Hello, YipYip!".utf8)
        let encrypted = try manager.encrypt(original)
        let decrypted = try manager.decrypt(encrypted)

        #expect(decrypted == original)
    }

    @Test("Different keys cannot decrypt each other's data")
    func differentKeys() throws {
        let key1 = Data(repeating: 0xAA, count: 32)
        let key2 = Data(repeating: 0xBB, count: 32)
        let manager1 = EncryptionManager(keyData: key1)
        let manager2 = EncryptionManager(keyData: key2)

        let original = Data("Secret".utf8)
        let encrypted = try manager1.encrypt(original)

        #expect(throws: (any Error).self) {
            _ = try manager2.decrypt(encrypted)
        }
    }

    @Test("Encrypted data differs from plaintext")
    func encryptedDiffers() throws {
        let key = Data(repeating: 0xCC, count: 32)
        let manager = EncryptionManager(keyData: key)

        let original = Data("Test content".utf8)
        let encrypted = try manager.encrypt(original)

        #expect(encrypted != original)
        #expect(encrypted.count > original.count) // Includes nonce + tag
    }

    @Test("Content hash is deterministic")
    func contentHashDeterministic() {
        let data = Data("consistent".utf8)
        let hash1 = EncryptionManager.contentHash(data)
        let hash2 = EncryptionManager.contentHash(data)
        #expect(hash1 == hash2)
    }

    @Test("Different content produces different hashes")
    func contentHashUnique() {
        let hash1 = EncryptionManager.contentHash(Data("alpha".utf8))
        let hash2 = EncryptionManager.contentHash(Data("beta".utf8))
        #expect(hash1 != hash2)
    }

    @Test("Empty data round-trips correctly")
    func emptyData() throws {
        let key = Data(repeating: 0xDD, count: 32)
        let manager = EncryptionManager(keyData: key)

        let original = Data()
        let encrypted = try manager.encrypt(original)
        let decrypted = try manager.decrypt(encrypted)
        #expect(decrypted == original)
    }

    @Test("Large data round-trips correctly")
    func largeData() throws {
        let key = Data(repeating: 0xEE, count: 32)
        let manager = EncryptionManager(keyData: key)

        let original = Data(repeating: 0x42, count: 1_000_000) // 1 MB
        let encrypted = try manager.encrypt(original)
        let decrypted = try manager.decrypt(encrypted)
        #expect(decrypted == original)
    }
}
