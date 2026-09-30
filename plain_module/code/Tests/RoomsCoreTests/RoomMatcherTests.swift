import XCTest
@testable import RoomsCore

final class RoomMatcherTests: XCTestCase {
    private func room(_ name: String, created: TimeInterval, shown: TimeInterval? = nil) -> Room {
        Room(name: name, windows: [], createdAt: Date(timeIntervalSince1970: created), lastShown: shown.map { Date(timeIntervalSince1970: $0) })
    }

    func testSubsequenceMatchIgnoresCase() {
        XCTAssertTrue(RoomMatcher.matches(query: "dw", name: "Deep Work"))
        XCTAssertTrue(RoomMatcher.matches(query: "DEEP", name: "deep work"))
        XCTAssertFalse(RoomMatcher.matches(query: "wd", name: "Deep Work"))
        XCTAssertTrue(RoomMatcher.matches(query: "", name: "Anything"))
    }

    func testRank() {
        XCTAssertEqual(RoomMatcher.rank(query: "de", name: "Design"), 0)
        XCTAssertEqual(RoomMatcher.rank(query: "wo", name: "Deep Work"), 1)
        XCTAssertEqual(RoomMatcher.rank(query: "sg", name: "Design"), 2)
    }

    func testDefaultOrder() {
        let a = room("A", created: 1), b = room("B", created: 2, shown: 50), c = room("C", created: 3, shown: 60), d = room("D", created: 0)
        XCTAssertEqual(RoomMatcher.defaultOrder([a, b, c, d]).map { $0.name }, ["C", "B", "D", "A"])
    }

    func testFilterOrdersByRankThenKeepsOrder() {
        let rooms = [room("Daily Build", created: 1), room("Deep Work", created: 2), room("Design", created: 3), room("Wide Desk", created: 4)]
        XCTAssertEqual(RoomMatcher.filter(rooms, query: "de").map { $0.name }, ["Deep Work", "Design", "Wide Desk"])
        XCTAssertEqual(RoomMatcher.filter(rooms, query: "").map { $0.name }, rooms.map { $0.name })
    }

    func testHasRoomNamed() {
        let rooms = [room("Design", created: 1)]
        XCTAssertTrue(RoomMatcher.hasRoom(named: "design", in: rooms))
        XCTAssertFalse(RoomMatcher.hasRoom(named: "design", in: rooms, excluding: rooms[0].id))
        XCTAssertFalse(RoomMatcher.hasRoom(named: "Desig", in: rooms))
    }
}
