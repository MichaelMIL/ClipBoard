import CryptoKit
import Foundation
import Security
import os

/// Encrypts clipboard history / favorites JSON at rest using AES-256-GCM.
///
/// Two on-disk envelopes are accepted on read:
/// - **CLP2** (current): AAD binds the ciphertext to its file role (history vs favorites) and a schema tag,
///   preventing swap or downgrade attacks.
/// - **CLP1** (legacy, read-only): early format with no AAD. Loaded for migration; the store rewrites the
///   file as CLP2 on the next save (via `persistenceFormatMismatch` in `ClipboardHistoryStore`).
///
/// A random 256-bit key is created on first use and stored in the login Keychain as a generic password
/// (`service = ClipboardApp.persistence`, `account = clipboard-store-v1`, accessibility
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Errors from Keychain are propagated rather than silently
/// regenerating the key — losing the key destroys all encrypted history, so the caller must surface failures.
public enum ClipboardPersistenceCrypto {
    private static let magicV1 = Data("CLP1".utf8)
    private static let magicV2 = Data("CLP2".utf8)
    private static let keychainService = "ClipboardApp.persistence"
    private static let keychainAccount = "clipboard-store-v1"

    private static let log = Logger(subsystem: "ClipboardApp", category: "Crypto")

    /// File role bound into AAD so a CLP2 ciphertext only authenticates against the matching file.
    public enum Role: String {
        case history
        case favorites

        fileprivate var aad: Data {
            Data("CLP2|\(rawValue)|v1".utf8)
        }
    }

    public enum EnvelopeKind {
        case plain
        case legacyV1
        case currentV2
    }

    public enum CryptoError: Error {
        case sealFailed
        case openFailed
        case keychainNotFound
        /// Existing Keychain item present but wrong size (32 bytes expected). Refuse to overwrite —
        /// the caller decides whether the old data is recoverable.
        case keychainCorrupted
        case keychainAccess(OSStatus)

        /// True when the failure indicates the file itself is unreadable (vs. a transient Keychain problem).
        /// `ClipboardHistoryStore` uses this to decide between quarantining the file and silently skipping load.
        public var indicatesFileCorruption: Bool {
            switch self {
            case .openFailed: return true
            case .sealFailed, .keychainNotFound, .keychainCorrupted, .keychainAccess: return false
            }
        }
    }

    public static func envelopeKind(of data: Data) -> EnvelopeKind {
        if data.count >= magicV2.count, data.prefix(magicV2.count) == magicV2 { return .currentV2 }
        if data.count >= magicV1.count, data.prefix(magicV1.count) == magicV1 { return .legacyV1 }
        return .plain
    }

    public static func isEncryptedFileFormat(_ data: Data) -> Bool {
        switch envelopeKind(of: data) {
        case .currentV2, .legacyV1: return true
        case .plain: return false
        }
    }

    /// Encrypts to the current envelope (CLP2 + role-bound AAD).
    public static func wrap(plaintextJSON plaintext: Data, role: Role) throws -> Data {
        let key = try loadOrCreateSymmetricKey()
        let sealed: AES.GCM.SealedBox
        do {
            sealed = try AES.GCM.seal(plaintext, using: key, authenticating: role.aad)
        } catch {
            throw CryptoError.sealFailed
        }
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        return magicV2 + combined
    }

    /// Decrypts a CLP2 or CLP1 file for the given role, or returns the original data if it is unwrapped JSON.
    /// CLP1 files have no AAD — they are decrypted as-is and the caller is expected to rewrite as CLP2.
    public static func unwrap(fileData: Data, role: Role) throws -> Data {
        switch envelopeKind(of: fileData) {
        case .plain:
            return fileData

        case .currentV2:
            let key = try loadOrCreateSymmetricKey()
            let box: AES.GCM.SealedBox
            do {
                box = try AES.GCM.SealedBox(combined: fileData.dropFirst(magicV2.count))
            } catch {
                throw CryptoError.openFailed
            }
            do {
                return try AES.GCM.open(box, using: key, authenticating: role.aad)
            } catch {
                throw CryptoError.openFailed
            }

        case .legacyV1:
            let key = try loadOrCreateSymmetricKey()
            let box: AES.GCM.SealedBox
            do {
                box = try AES.GCM.SealedBox(combined: fileData.dropFirst(magicV1.count))
            } catch {
                throw CryptoError.openFailed
            }
            do {
                return try AES.GCM.open(box, using: key)
            } catch {
                throw CryptoError.openFailed
            }
        }
    }

    // MARK: - Keychain

    private static func loadOrCreateSymmetricKey() throws -> SymmetricKey {
        do {
            let existing = try readKeyDataFromKeychain()
            guard existing.count == 32 else {
                // Item is present but malformed. Do NOT regenerate — that would destroy any data encrypted
                // under the previous key. Surface the error so the caller can warn the user.
                log.error("Keychain key has unexpected size \(existing.count, privacy: .public); refusing to overwrite.")
                throw CryptoError.keychainCorrupted
            }
            return SymmetricKey(data: existing)
        } catch CryptoError.keychainNotFound {
            return try createAndStoreNewKey()
        }
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
        switch status {
        case errSecSuccess:
            guard let data = out as? Data else { throw CryptoError.keychainAccess(status) }
            return data
        case errSecItemNotFound:
            throw CryptoError.keychainNotFound
        default:
            log.error("Keychain read failed: OSStatus \(status, privacy: .public)")
            throw CryptoError.keychainAccess(status)
        }
    }

    private static func createAndStoreNewKey() throws -> SymmetricKey {
        var bytes = [UInt8](repeating: 0, count: 32)
        let r = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard r == errSecSuccess else { throw CryptoError.keychainAccess(r) }
        let data = Data(bytes)

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return SymmetricKey(data: data)
        case errSecDuplicateItem:
            // Lost a race with another caller. The first writer's key is authoritative — load it instead
            // of overwriting (which would orphan everything they sealed under the original key).
            return SymmetricKey(data: try readKeyDataFromKeychain())
        default:
            log.error("Keychain add failed: OSStatus \(status, privacy: .public)")
            throw CryptoError.keychainAccess(status)
        }
    }
}
