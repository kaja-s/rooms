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

final class DeleteRoomTests: XCTestCase {
    private func seed(_ h: Harness) -> [Room] {
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.seed([Room(name: "One", windows: [a], createdAt: Date(timeIntervalSince1970: 1)),
                Room(name: "Two", windows: [b], createdAt: Date(timeIntervalSince1970: 2)),
                Room(name: "Three", windows: [a, b], createdAt: Date(timeIntervalSince1970: 3))])
        return h.controller.rooms
    }

    func testDeleteButtonRemovesAndPersists() {
        let h = Harness()
        _ = seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.clickDeleteButton(1)
        XCTAssertEqual(h.controller.rooms.map { $0.name }, ["One", "Three"])
        XCTAssertEqual(h.reload().map { $0.name }, ["One", "Three"])
    }

    func testContextMenuDelete() {
        let h = Harness()
        _ = seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.performContextMenu(.delete, onRow: 0)
        XCTAssertEqual(h.reload().map { $0.name }, ["Two", "Three"])
    }

    func testAcceptanceCommandDeleteOnCurrentRoom() {
        let h = Harness()
        let rooms = seed(h)
        h.controller.showRoom(id: rooms[1].id)
        h.fake.clearOperations()
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.selectedRoom?.name, "Two", "current room is listed first")
        palette.pressCommandDelete()
        XCTAssertNil(h.controller.currentRoomID)
        XCTAssertEqual(h.controller.statusMenu.headerTitle, "No room")
        XCTAssertTrue(h.fake.operations.isEmpty, "no window moved, hidden, minimized, or closed")
        XCTAssertEqual(h.fake.windows.count, 2)
        XCTAssertEqual(palette.selectedIndex, 0, "the row below becomes selected")
        XCTAssertEqual(palette.selectedRoom?.name, "One")
        palette.moveSelection(by: 5)
        XCTAssertEqual(palette.selectedRoom?.name, "Three")
        palette.pressCommandDelete()
        XCTAssertEqual(palette.selectedIndex, 0, "deleting the last row selects the new last row")
        XCTAssertEqual(palette.selectedRoom?.name, "One")
    }
}
