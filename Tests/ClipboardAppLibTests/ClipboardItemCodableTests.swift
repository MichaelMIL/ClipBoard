import XCTest
@testable import ClipboardAppLib

/// `ClipboardItem` ships a hand-written `Codable` that uses `text` and `filePaths` as discriminator keys
/// (instead of the enum's automatic encoding). Persisted history files depend on this exact shape —
/// changing it without a migration would silently drop everything users have saved.
final class ClipboardItemCodableTests: XCTestCase {
    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// ISO8601 (without fractional seconds) is the on-disk format, so any timestamp we use in a round-trip
    /// test must already be whole-second so the decoded value matches by `==`.
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testTextItemRoundTrip() throws {
        let original = ClipboardItem(id: UUID(), created: Self.fixedDate, content: .text("hello world"))
        let data = try encoder().encode(original)
        let decoded = try decoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, original)

        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"text\""), "Text items must serialize under the 'text' key")
        XCTAssertFalse(json.contains("filePaths"), "Text items must not emit a filePaths key")
    }

    func testFilesItemRoundTrip() throws {
        let paths = ["/tmp/a.txt", "/Users/test/Documents/b.pdf"]
        let original = ClipboardItem(id: UUID(), created: Self.fixedDate, content: .files(paths))
        let data = try encoder().encode(original)
        let decoded = try decoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, original)

        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"filePaths\""), "File items must serialize under the 'filePaths' key")
        XCTAssertFalse(json.contains("\"text\""), "File items must not emit a text key")
    }

    func testDecodePicksFilesWhenBothKeysPresent() throws {
        // Decoder prefers `filePaths` when both are present and non-empty — matches the production order.
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "created": "2026-01-01T00:00:00Z",
          "text": "fallback text",
          "filePaths": ["/tmp/file.txt"]
        }
        """
        let decoded = try decoder().decode(ClipboardItem.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.content, .files(["/tmp/file.txt"]))
    }

    func testDecodeFallsBackToTextWhenFilePathsEmpty() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "created": "2026-01-01T00:00:00Z",
          "text": "the text",
          "filePaths": []
        }
        """
        let decoded = try decoder().decode(ClipboardItem.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.content, .text("the text"))
    }

    func testDecodeFailsWhenNeitherKeyPresent() {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "created": "2026-01-01T00:00:00Z"
        }
        """
        XCTAssertThrowsError(try decoder().decode(ClipboardItem.self, from: Data(json.utf8)))
    }

    func testCollectionRoundTrip() throws {
        let items: [ClipboardItem] = [
            ClipboardItem(id: UUID(), created: Self.fixedDate, content: .text("one")),
            ClipboardItem(id: UUID(), created: Self.fixedDate, content: .files(["/a", "/b"])),
            ClipboardItem(id: UUID(), created: Self.fixedDate, content: .text("three")),
        ]
        let data = try encoder().encode(items)
        let decoded = try decoder().decode([ClipboardItem].self, from: data)
        XCTAssertEqual(decoded, items)
    }
}
