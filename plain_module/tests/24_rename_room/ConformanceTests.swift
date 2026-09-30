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

final class RenameRoomTests: XCTestCase {
    private func seed(_ h: Harness) -> [Room] {
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a]), Room(name: "Deep Work", windows: [a])])
        return h.controller.rooms
    }

    func testDialogFromContextMenu() {
        let h = Harness()
        let rooms = seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.performContextMenu(.rename, onRow: 0)
        let dialog = h.controller.renameDialog!
        XCTAssertEqual(dialog.roomID, rooms[0].id)
        XCTAssertEqual(dialog.title, "Rename “Design”")
        XCTAssertEqual(dialog.text, "Design")
        XCTAssertEqual(dialog.cancelButtonTitle, "Cancel")
        XCTAssertEqual(dialog.renameButtonTitle, "Rename")
        dialog.cancel()
        XCTAssertNil(h.controller.renameDialog)
        XCTAssertEqual(h.controller.rooms[0].name, "Design")
    }

    func testDialogFromStatusMenuForCurrentRoom() {
        let h = Harness()
        let rooms = seed(h)
        h.controller.showRoom(id: rooms[1].id)
        h.controller.statusMenu.perform(.rename)
        XCTAssertEqual(h.controller.renameDialog?.title, "Rename “Deep Work”")
    }

    func testAcceptanceDuplicateThenSuccess() {
        let h = Harness()
        let rooms = seed(h)
        h.controller.beginRename(ofRoom: rooms[0].id)
        let dialog = h.controller.renameDialog!
        dialog.text = "deep work"
        XCTAssertFalse(dialog.isRenameEnabled)
        XCTAssertEqual(dialog.errorMessage, "A room with this name already exists")
        XCTAssertFalse(dialog.confirm(), "↵ does nothing while Rename is disabled")
        dialog.text = "Design 2"
        XCTAssertTrue(dialog.isRenameEnabled)
        XCTAssertNil(dialog.errorMessage)
        XCTAssertTrue(dialog.confirm())
        XCTAssertNil(h.controller.renameDialog)
        XCTAssertEqual(h.reload()[0].name, "Design 2")
    }

    func testEmptyOrOwnNameRules() {
        let h = Harness()
        let rooms = seed(h)
        h.controller.beginRename(ofRoom: rooms[0].id)
        let dialog = h.controller.renameDialog!
        dialog.text = "   "
        XCTAssertFalse(dialog.isRenameEnabled)
        XCTAssertNil(dialog.errorMessage)
        dialog.text = "DESIGN"
        XCTAssertTrue(dialog.isRenameEnabled, "a room may keep its own name in another case")
        XCTAssertTrue(dialog.confirm())
        XCTAssertEqual(h.controller.rooms[0].name, "DESIGN")
    }
}
