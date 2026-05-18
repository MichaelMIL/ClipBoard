import XCTest
@testable import ClipboardAppLib

final class ClipboardItemPreviewTests: XCTestCase {
    func testTextPreviewShorterThanMaxIsReturnedAsIs() {
        XCTAssertEqual(ClipboardItem.Content.text("hello").previewString(), "hello")
    }

    func testTextPreviewLongerThanMaxIsTruncatedWithEllipsis() {
        let long = String(repeating: "a", count: 500)
        let preview = ClipboardItem.Content.text(long).previewString(maxLength: 400)
        XCTAssertEqual(preview.count, 401, "Should be 400 chars + 1 ellipsis character")
        XCTAssertTrue(preview.hasSuffix("…"))
    }

    func testSingleFilePreviewIsLastPathComponent() {
        let preview = ClipboardItem.Content.files(["/Users/test/Documents/report.pdf"]).previewString()
        XCTAssertEqual(preview, "report.pdf")
    }

    func testTwoFilePreviewJoinsNames() {
        let preview = ClipboardItem.Content.files(["/a/one.txt", "/b/two.txt"]).previewString()
        XCTAssertEqual(preview, "one.txt, two.txt")
    }

    func testManyFilePreviewSummarizesRemainder() {
        let paths = (1 ... 7).map { "/dir/file\($0).txt" }
        let preview = ClipboardItem.Content.files(paths).previewString()
        XCTAssertEqual(preview, "file1.txt, file2.txt, file3.txt … +4 more")
    }
}
