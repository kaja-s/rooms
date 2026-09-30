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

final class MenuBarAppTests: XCTestCase {
    func testMenuItemsInOrderWithoutCurrentRoom() {
        let h = Harness()
        let items = h.controller.statusMenu.items
        XCTAssertEqual(items.map { $0.title }, ["No room", "Show Palette", "Edit Windows…", "Rename…", "Getting Started", "Quit Rooms"])
        XCTAssertEqual(items.map { $0.action }, [.header, .showPalette, .editWindows, .rename, .gettingStarted, .quit])
        XCTAssertFalse(items[0].isEnabled, "header is disabled")
        XCTAssertEqual(items[1].keyEquivalentHint, "⌥Space")
        XCTAssertFalse(items[2].isEnabled)
        XCTAssertFalse(items[3].isEnabled)
        XCTAssertTrue(items[4].isEnabled)
        XCTAssertTrue(items[5].isEnabled)
    }

    func testHeaderAndItemsWithCurrentRoom() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a])])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        let items = h.controller.statusMenu.items
        XCTAssertEqual(items[0].title, "Design")
        XCTAssertFalse(items[0].isEnabled)
        XCTAssertTrue(items[2].isEnabled)
        XCTAssertTrue(items[3].isEnabled)
    }

    func testQuitRoomsQuits() {
        let h = Harness()
        var quit = false
        h.controller.onQuit = { quit = true }
        h.controller.statusMenu.perform(.quit)
        XCTAssertTrue(quit)
        XCTAssertTrue(h.controller.quitRequested)
    }
}
