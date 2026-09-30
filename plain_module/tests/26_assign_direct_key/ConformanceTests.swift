import XCTest
@testable import RoomsCore
@testable import RoomsKit

/// Drives `AppController` through `FakeWindowSystem` with a `RoomStore` in a fresh temporary directory.
final class Harness {
    let fake = FakeWindowSystem()
    let directory: URL
    let store: RoomStore
    let defaults: UserDefaults
    let controller: AppController
    let area = CGRect(x: 0, y: 0, width: 1440, height: 900)

    init(firstLaunch: Bool = false) {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("rooms-conformance-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = RoomStore(fileURL: directory.appendingPathComponent("rooms.json"))
        defaults = UserDefaults(suiteName: "dev.rooms.conformance.\(UUID().uuidString)")!
        if !firstLaunch { defaults.set(true, forKey: AppController.hasLaunchedBeforeKey) }
        fake.visibleArea = area
        controller = AppController(store: store, windowSystem: fake, defaults: defaults)
        controller.start()
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    func reload() -> [Room] { RoomStore(fileURL: store.fileURL).load() }

    @discardableResult
    func app(_ bundle: String, pid: Int32, name: String) -> RunningApplication {
        fake.addApplication(bundleIdentifier: bundle, processIdentifier: pid, name: name)
    }

    @discardableResult
    func window(_ app: RunningApplication, id: UInt32, title: String, frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
                minimumSize: CGSize = CGSize(width: 300, height: 200), minimized: Bool = false, standard: Bool = true, own: Bool = false) -> AppWindow {
        let identity = fake.addWindow(of: app, windowID: id, title: title, frame: frame, minimumSize: minimumSize, isMinimized: minimized, isStandard: standard, isRoomsOwn: own)
        return AppWindow(identity: identity, applicationName: app.name, title: title, frame: frame, minimumSize: minimumSize)
    }

    func seed(_ rooms: [Room]) {
        try! store.save(rooms)
        controller.start()
    }
}

final class AssignDirectKeyTests: XCTestCase {
    func testAcceptanceKeyMovesBetweenRoomsAndClears() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "A", windows: [a], createdAt: Date(timeIntervalSince1970: 1)), Room(name: "B", windows: [a], createdAt: Date(timeIntervalSince1970: 2))])
        let idA = h.controller.rooms[0].id, idB = h.controller.rooms[1].id
        let palette = h.controller.palette
        palette.open()
        XCTAssertTrue(palette.footerHints.contains("⌘1–9 Key"))
        palette.pressCommandDigit(3)
        XCTAssertEqual(h.controller.room(idA)?.directKey, 3)
        XCTAssertEqual(h.reload()[0].directKey, 3)
        palette.moveSelection(by: 1)
        palette.pressCommandDigit(3)
        XCTAssertNil(h.controller.room(idA)?.directKey)
        XCTAssertEqual(h.controller.room(idB)?.directKey, 3)
        XCTAssertNil(h.reload()[0].directKey)
        XCTAssertEqual(h.reload()[1].directKey, 3)
        palette.pressCommandDigit(3)
        XCTAssertNil(h.controller.room(idB)?.directKey)
        XCTAssertNil(h.reload()[1].directKey)
    }

    func testOtherKeysAreIndependentAndRowShowsKey() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "A", windows: [a]), Room(name: "B", windows: [a], directKey: 9)])
        let palette = h.controller.palette
        palette.open()
        palette.pressCommandDigit(1)
        XCTAssertEqual(h.controller.rooms[1].directKey, 9)
        guard case .room(let row) = palette.rows[0] else { return XCTFail("room row") }
        XCTAssertEqual(row.trailer, "⌃⌥1")
        palette.pressCommandDigit(0)
        XCTAssertEqual(h.controller.rooms[0].directKey, 1, "only 1 to 9 are keys")
    }
}
