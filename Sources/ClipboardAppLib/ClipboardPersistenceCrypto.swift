import CryptoKit
import Foundation
import Security

/// Encrypts clipboard history / favorites JSON at rest using AES-256-GCM.
/// A random key is created on first use and stored in the login keychain.
/// Files written with a ``magic`` prefix; legacy plaintext JSON (no prefix) still loads and is rewritten encrypted on next save.
enum ClipboardPersistenceCrypto {
    private static let magic = Data("CLP1".utf8)
    private static let keychainService = "ClipboardApp.persistence"
    private static let keychainAccount = "clipboard-store-v1"

    enum CryptoError: Error {
        case sealFailed
        case keychain(OSStatus)
    }

    /// `true` if data was written by ``wrapPlaintextJSON(_:)`` (starts with version magic).
    static func isEncryptedFileFormat(_ data: Data) -> Bool {
        data.count >= magic.count && data.prefix(magic.count) == magic
    }

    static func wrapPlaintextJSON(_ plaintext: Data) throws -> Data {
        let key = try loadOrCreateSymmetricKey()
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        return magic + combined
    }

    /// Returns decrypted payload, or the original data if it is not wrapped (legacy plaintext).
    static func unwrapToPlaintextJSON(_ fileData: Data) throws -> Data {
        guard fileData.count >= magic.count, fileData.prefix(magic.count) == magic else {
            return fileData
        }
        let boxBytes = fileData.dropFirst(magic.count)
        let key = try loadOrCreateSymmetricKey()
        let box = try AES.GCM.SealedBox(combined: boxBytes)
        return try AES.GCM.open(box, using: key)
    }

    private static func loadOrCreateSymmetricKey() throws -> SymmetricKey {
        if let existing = try? readKeyDataFromKeychain(), existing.count == 32 {
            return SymmetricKey(data: existing)
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw CryptoError.keychain(status)
        }
        let data = Data(bytes)
        try storeKeyInKeychain(data)
        return SymmetricKey(data: data)
    }

    private static func readKeyDataFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else {
            throw CryptoError.keychain(status)
        }
        return data
    }

    private static func storeKeyInKeychain(_ keyData: Data) throws {
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ] as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw CryptoError.keychain(status) }
    }
}
