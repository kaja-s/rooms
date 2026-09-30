import XCTest
@testable import RoomsCore

final class RoomStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("roomstore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func sampleRoom() -> Room {
        let window = AppWindow(identity: WindowIdentity(bundleIdentifier: "com.a", processIdentifier: 7, windowID: 9), applicationName: "A", title: "T",
                               frame: CGRect(x: 1, y: 2, width: 300, height: 200), minimumSize: CGSize(width: 100, height: 50))
        return Room(name: "Design", windows: [window], layout: .focus, directKey: 3,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000), lastShown: Date(timeIntervalSince1970: 1_700_000_100))
    }

    func testMissingFileIsEmpty() {
        let store = RoomStore(fileURL: directory.appendingPathComponent("rooms.json"))
        XCTAssertEqual(store.load(), [])
    }

    func testRoundTrip() throws {
        let url = directory.appendingPathComponent("nested/rooms.json")
        let store = RoomStore(fileURL: url)
        let room = sampleRoom()
        try store.save([room])
        XCTAssertEqual(RoomStore(fileURL: url).load(), [room])
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("2023-11-14T22:13:20Z"), "dates are ISO 8601")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("nested").appendingPathComponent(".rooms.json.tmp").path))
    }

    func testOverwriteReplacesAtomically() throws {
        let url = directory.appendingPathComponent("rooms.json")
        let store = RoomStore(fileURL: url)
        try store.save([sampleRoom()])
        try store.save([])
        XCTAssertEqual(store.load(), [])
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testCorruptFileIsKeptAndTreatedAsEmpty() throws {
        let url = directory.appendingPathComponent("rooms.json")
        try "not json".write(to: url, atomically: true, encoding: .utf8)
        let store = RoomStore(fileURL: url)
        XCTAssertEqual(store.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let corrupt = directory.appendingPathComponent("rooms.json.corrupt")
        XCTAssertEqual(try String(contentsOf: corrupt, encoding: .utf8), "not json")
    }

    func testDefaultLocation() {
        XCTAssertTrue(RoomStore.defaultFileURL.path.hasSuffix("/Library/Application Support/Rooms/rooms.json"))
    }
}
