import XCTest
@testable import ClipboardAppLib

final class AppSettingsTests: XCTestCase {
    func testClampHistoryCountWithinRange() {
        XCTAssertEqual(AppSettings.clampHistoryCount(10), 10)
        XCTAssertEqual(AppSettings.clampHistoryCount(50), 50)
        XCTAssertEqual(AppSettings.clampHistoryCount(200), 200)
    }

    func testClampHistoryCountBelowMinimum() {
        XCTAssertEqual(AppSettings.clampHistoryCount(0), 10)
        XCTAssertEqual(AppSettings.clampHistoryCount(-100), 10)
        XCTAssertEqual(AppSettings.clampHistoryCount(9), 10)
    }

    func testClampHistoryCountAboveMaximum() {
        XCTAssertEqual(AppSettings.clampHistoryCount(201), 200)
        XCTAssertEqual(AppSettings.clampHistoryCount(10_000), 200)
        XCTAssertEqual(AppSettings.clampHistoryCount(.max), 200)
    }
}
