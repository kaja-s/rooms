import AppKit
import XCTest
@testable import RoomsKit

final class RoomsAppTests: XCTestCase {
    func testLightAppearanceRegardlessOfSystemAppearance() {
        XCTAssertEqual(RoomsApp.appearanceName, .aqua)
        XCTAssertEqual(RoomsApp.appearance?.name, .aqua)
        XCTAssertNotEqual(RoomsApp.appearance?.name, .darkAqua)
    }
}
