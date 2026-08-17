import CryptoKit
import Foundation

/// Encrypts and decrypts clipboard content using AES-256-GCM with a Keychain-stored key.
public final class EncryptionManager: Sendable {
    private let symmetricKey: SymmetricKey

    public init(keyData: Data) {
        self.symmetricKey = SymmetricKey(data: keyData)
    }

    public convenience init(keychainManager: KeychainManager) throws {
        let keyData = try keychainManager.retrieveOrCreateKey()
        self.init(keyData: keyData)
    }

    public func encrypt(_ plaintext: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    public func decrypt(_ ciphertext: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    /// SHA-256 hash of the plaintext, used for deduplication.
    public static func contentHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

public enum EncryptionError: Error, LocalizedError, Sendable {
    case sealFailed
    case decryptionFailed

    public var errorDescription: String? {
        switch self {
        case .sealFailed:
            return "Failed to encrypt data."
        case .decryptionFailed:
            return "Failed to decrypt data. The encryption key may have changed."
        }
    }
}
