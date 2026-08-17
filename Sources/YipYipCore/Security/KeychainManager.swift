import Foundation
import Security

/// Manages encryption keys in the macOS Keychain.
public final class KeychainManager: Sendable {
    private let service: String

    public init(service: String = "com.benatakan.yipyip.encryption-key") {
        self.service = service
    }

    public func retrieveOrCreateKey() throws -> Data {
        if let existing = try retrieveKey() {
            return existing
        }
        let newKey = generateKey()
        try storeKey(newKey)
        return newKey
    }

    public func retrieveKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "master-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.osStatus(status)
        }
    }

    public func storeKey(_ key: Data) throws {
        // Delete existing first to avoid duplicates.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "master-key",
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "master-key",
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.osStatus(status)
        }
    }

    public func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "master-key",
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.osStatus(status)
        }
    }

    private func generateKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate random key")
        return Data(bytes)
    }
}

public enum KeychainError: Error, LocalizedError, Sendable {
    case unexpectedData
    case osStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "Unexpected data format in Keychain."
        case .osStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown"
            return "Keychain error (\(status)): \(message)"
        }
    }
}
