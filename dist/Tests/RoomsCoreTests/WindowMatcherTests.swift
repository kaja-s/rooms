import XCTest
@testable import RoomsCore

final class WindowMatcherTests: XCTestCase {
    private func window(_ bundle: String, _ pid: Int32, _ id: UInt32, _ title: String) -> AppWindow {
        AppWindow(identity: WindowIdentity(bundleIdentifier: bundle, processIdentifier: pid, windowID: id), applicationName: bundle, title: title, frame: .zero)
    }

    func testIdentityWins() {
        let saved = [window("a", 1, 10, "One")]
        let open = [window("a", 1, 11, "One"), window("a", 1, 10, "Renamed")]
        XCTAssertEqual(WindowMatcher.match(saved: saved, among: open), [open[1]])
    }

    func testTitleFallbackAfterRelaunch() {
        let saved = [window("a", 1, 10, "One")]
        let open = [window("a", 2, 30, "Two"), window("a", 2, 31, "One")]
        XCTAssertEqual(WindowMatcher.match(saved: saved, among: open), [open[1]])
    }

    func testFirstUnmatchedOfSameApplicationEachAtMostOnce() {
        let saved = [window("a", 1, 10, "One"), window("a", 1, 11, "Two")]
        let open = [window("b", 3, 1, "One"), window("a", 2, 30, "X"), window("a", 2, 31, "Y")]
        XCTAssertEqual(WindowMatcher.match(saved: saved, among: open), [open[1], open[2]])
    }

    func testNotRunningIsNotFound() {
        let saved = [window("a", 1, 10, "One")]
        XCTAssertEqual(WindowMatcher.match(saved: saved, among: [window("b", 3, 1, "One")]), [nil])
    }

    func testTitleMatchDoesNotStealIdentityMatch() {
        let saved = [window("a", 1, 10, "Same"), window("a", 1, 11, "Same")]
        let open = [window("a", 1, 11, "Same"), window("a", 1, 12, "Same")]
        XCTAssertEqual(WindowMatcher.match(saved: saved, among: open), [open[1], open[0]])
    }
}
