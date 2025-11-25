import XCTest
@testable import OmniSync

final class SyncParserTests: XCTestCase {
    func testParseProgress() {
        XCTAssertEqual(RsyncRunner.parseProgress(from: "      12%   4.13MB/s"), 0.12, accuracy: 0.001)
        XCTAssertEqual(RsyncRunner.parseProgress(from: "100%"), 1.0, accuracy: 0.001)
        XCTAssertNil(RsyncRunner.parseProgress(from: "sending incremental file list"))
    }

    func testParseSpeed() {
        XCTAssertEqual(RsyncRunner.parseSpeed(from: "      12%   4.13MB/s    0:00:01"), "4.13MB/s")
        XCTAssertNil(RsyncRunner.parseSpeed(from: "sending incremental file list"))
    }
}
