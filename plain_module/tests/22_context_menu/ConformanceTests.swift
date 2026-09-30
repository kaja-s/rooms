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

final class ContextMenuTests: XCTestCase {
    func testContextMenuItems() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "R", windows: [a])])
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.contextMenuItems(forRow: 0).map { $0.title }, ["Edit Windows…", "Rename…", "Delete"])
        XCTAssertEqual(palette.contextMenuItems(forRow: 0).map { $0.action }, [.editWindows, .rename, .delete])
        palette.query = "New"
        XCTAssertTrue(palette.contextMenuItems(forRow: 1).isEmpty, "no context menu on the Create row")
    }

    func testSelectedRowShowsReturnAndDeleteButton() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "R1", windows: [a], directKey: 2), Room(name: "R2", windows: [a])])
        let palette = h.controller.palette
        palette.open()
        XCTAssertTrue(palette.rowShowsReturnAndDelete(at: 0))
        XCTAssertFalse(palette.rowShowsReturnAndDelete(at: 1))
        guard case .room(let row) = palette.rows[0] else { return XCTFail("room row") }
        XCTAssertEqual(row.trailer, "⌃⌥2", "trailer precedes ↵ and ⓧ")
        palette.moveSelection(by: 1)
        XCTAssertFalse(palette.rowShowsReturnAndDelete(at: 0))
        XCTAssertTrue(palette.rowShowsReturnAndDelete(at: 1))
    }
}
