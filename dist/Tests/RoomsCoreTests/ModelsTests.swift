import XCTest
@testable import RoomsCore

final class ModelsTests: XCTestCase {
    func testLayoutNamesAndOrders() {
        XCTAssertEqual(Layout.allCases.map { $0.displayName }, ["Auto", "Focus", "Columns", "Grid", "Stack"])
        XCTAssertEqual(Layout.cycleOrder, [.auto, .focus, .columns, .grid, .stack])
        XCTAssertEqual(Layout.tidyLayouts, [.focus, .columns, .grid])
    }

    func testRoomDefaults() {
        let room = Room(name: "R", windows: [])
        XCTAssertEqual(room.layout, .auto)
        XCTAssertNil(room.directKey)
        XCTAssertNil(room.lastShown)
    }

    func testLegacyMyLayoutLoadsAsAutoAndFramesAreIgnored() throws {
        let json = #"{"id":"BC800FEA-A050-4A1B-88BE-8480B1164654","name":"test","windows":[],"layout":"myLayout","myLayoutFrames":[[[0,0],[10,10]]],"createdAt":0}"#
        let room = try JSONDecoder().decode(Room.self, from: Data(json.utf8))
        XCTAssertEqual(room.layout, .auto)
        XCTAssertThrowsError(try JSONDecoder().decode(Layout.self, from: Data(#""bogus""#.utf8)))
    }

    func testAppWindowCodable() throws {
        let window = AppWindow(identity: WindowIdentity(bundleIdentifier: "b", processIdentifier: 1, windowID: 2), applicationName: "App", title: "", frame: CGRect(x: 1, y: 2, width: 3, height: 4), minimumSize: CGSize(width: 5, height: 6))
        let data = try JSONEncoder().encode(window)
        XCTAssertEqual(try JSONDecoder().decode(AppWindow.self, from: data), window)
        XCTAssertEqual(window.bundleIdentifier, "b")
        XCTAssertEqual(window.processIdentifier, 1)
    }
}
