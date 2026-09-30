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

final class DirectKeyHotkeysTests: XCTestCase {
    func testHotkeyShowsTheRoomWithThatKey() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(y, id: 2, title: "B")
        h.seed([Room(name: "A", windows: [a], directKey: 1), Room(name: "B", windows: [b], layout: .columns, directKey: 2)])
        h.controller.directKeyPressed(2)
        XCTAssertEqual(h.controller.currentRoom?.name, "B")
        XCTAssertEqual(h.fake.frame(of: b.identity), LayoutEngine.frames(for: .columns, count: 1, in: h.area)[0])
        XCTAssertTrue(h.fake.isHidden(application: 1))
        XCTAssertEqual(h.fake.focusedByOperation, b.identity)
        XCTAssertNotNil(h.controller.room(h.controller.rooms[1].id)?.lastShown)
    }

    func testNoRoomWithThatKeyDoesNothing() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "A", windows: [a], directKey: 1)])
        h.controller.directKeyPressed(5)
        XCTAssertNil(h.controller.currentRoomID)
        XCTAssertTrue(h.fake.operations.isEmpty)
        XCTAssertNil(h.controller.notificationMessage)
    }
}
