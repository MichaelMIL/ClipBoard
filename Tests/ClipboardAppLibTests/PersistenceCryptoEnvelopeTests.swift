import XCTest
@testable import ClipboardAppLib

/// Envelope detection runs on every load and is the seam that drives the legacy-CLP1 → CLP2 rewrite path.
/// Keychain-backed seal/open is exercised through the manual test plan; here we cover only the parts that
/// do not require a real Keychain entry (and therefore are safe to run on CI without polluting the user's
/// login keychain).
final class PersistenceCryptoEnvelopeTests: XCTestCase {
    private let plain: Data = {
        let json = #"[{"id":"11111111-1111-1111-1111-111111111111","created":"2026-01-01T00:00:00Z","text":"hi"}]"#
        return Data(json.utf8)
    }()

    private let clp1Bytes = Data("CLP1".utf8) + Data([0x00, 0x01, 0x02, 0x03])
    private let clp2Bytes = Data("CLP2".utf8) + Data([0x00, 0x01, 0x02, 0x03])

    func testEnvelopeKindDetectsPlain() {
        XCTAssertEqual(ClipboardPersistenceCrypto.envelopeKind(of: plain), .plain)
    }

    func testEnvelopeKindDetectsLegacyV1() {
        XCTAssertEqual(ClipboardPersistenceCrypto.envelopeKind(of: clp1Bytes), .legacyV1)
    }

    func testEnvelopeKindDetectsCurrentV2() {
        XCTAssertEqual(ClipboardPersistenceCrypto.envelopeKind(of: clp2Bytes), .currentV2)
    }

    func testIsEncryptedFileFormatMatchesEnvelopeDecisions() {
        XCTAssertFalse(ClipboardPersistenceCrypto.isEncryptedFileFormat(plain))
        XCTAssertTrue(ClipboardPersistenceCrypto.isEncryptedFileFormat(clp1Bytes))
        XCTAssertTrue(ClipboardPersistenceCrypto.isEncryptedFileFormat(clp2Bytes))
    }

    func testTruncatedMagicIsPlain() {
        // A file shorter than the magic must be treated as plain — never as a malformed envelope.
        XCTAssertEqual(ClipboardPersistenceCrypto.envelopeKind(of: Data("CLP".utf8)), .plain)
        XCTAssertEqual(ClipboardPersistenceCrypto.envelopeKind(of: Data()), .plain)
    }

    func testCryptoErrorFileCorruptionFlag() {
        // The store branches on this to decide between quarantining the file and silently skipping load.
        // A regression here would either lose data (false positive) or hide a real problem (false negative).
        XCTAssertTrue(ClipboardPersistenceCrypto.CryptoError.openFailed.indicatesFileCorruption)
        XCTAssertFalse(ClipboardPersistenceCrypto.CryptoError.sealFailed.indicatesFileCorruption)
        XCTAssertFalse(ClipboardPersistenceCrypto.CryptoError.keychainNotFound.indicatesFileCorruption)
        XCTAssertFalse(ClipboardPersistenceCrypto.CryptoError.keychainCorrupted.indicatesFileCorruption)
        XCTAssertFalse(ClipboardPersistenceCrypto.CryptoError.keychainAccess(-25300).indicatesFileCorruption)
    }

    func testUnwrapReturnsPlainDataUnchanged() throws {
        // The plain path doesn't touch Keychain — safe to assert here.
        let out = try ClipboardPersistenceCrypto.unwrap(fileData: plain, role: .history)
        XCTAssertEqual(out, plain)
    }
}
