import XCTest
@testable import ClipboardApp

final class GitHubVersionTests: XCTestCase {
    // MARK: - isValidVersionTag

    func testValidReleaseTags() {
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("1.2.0"))
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("v1.2.0"))
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("V0.0.1"))
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("1.2.0-alpha.1"))
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("1.2.0-beta.42"))
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("1.2.0-rc.1"))
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("1.2"))           // two-segment is permitted
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("1.2.3.4"))       // four-segment is permitted
        XCTAssertTrue(GitHubUpdateCheck.isValidVersionTag("  1.2.0  "))     // surrounding whitespace tolerated
    }

    /// Inputs that previously slipped through `compareVersions` by being silently coerced to `0`.
    /// L12 says fail closed instead.
    func testInvalidTagsAreRejected() {
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag(""))
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag("not-a-version"))
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag("v1.foo.0"))
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag("1"))             // single-segment rejected
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag("1.2.3-gamma.1")) // unsupported pre-release tag
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag("1.2.3-alpha"))   // missing pre-release number
        XCTAssertFalse(GitHubUpdateCheck.isValidVersionTag("javascript:alert(1)"))
    }

    // MARK: - compareVersions

    func testCompareNumericallyHigher() {
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("1.10.0", "1.9.0"), .orderedDescending)
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("v2.0.0", "1.99.99"), .orderedDescending)
    }

    func testCompareEqual() {
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("1.2.0", "1.2.0"), .orderedSame)
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("v1.2.0", "1.2.0"), .orderedSame)
        // Pre-release suffix is intentionally ignored at this layer — UpdateAvailableNotifier de-dupes
        // notifications on the raw tag, so 1.2.0 vs 1.2.0-alpha.1 won't notify if the user is on 1.2.0.
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("1.2.0", "1.2.0-beta.1"), .orderedSame)
    }

    func testCompareDifferentSegmentLengths() {
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("1.2", "1.2.0"), .orderedSame)
        XCTAssertEqual(GitHubUpdateCheck.compareVersions("1.2", "1.2.1"), .orderedAscending)
    }
}
