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

final class ShowRoomSetsCurrentTests: XCTestCase {
    func testCurrentRoomLastShownAndPersistence() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a]), Room(name: "Build", windows: [a])])
        let id = h.controller.rooms[1].id
        XCTAssertNil(h.controller.currentRoom)
        let before = Date()
        h.controller.showRoom(id: id)
        XCTAssertEqual(h.controller.currentRoomID, id)
        XCTAssertEqual(h.controller.currentRoom?.name, "Build")
        let shown = h.controller.room(id)!.lastShown!
        XCTAssertGreaterThanOrEqual(shown.timeIntervalSince1970 + 1, before.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(shown.timeIntervalSinceNow, 1)
        let reloaded = h.reload()
        XCTAssertNotNil(reloaded[1].lastShown)
        XCTAssertNil(reloaded[0].lastShown)
        XCTAssertEqual(h.controller.statusMenu.headerTitle, "Build")
        XCTAssertEqual(h.controller.statusMenu.items[0].title, "Build")
    }

    func testCurrentChangesOnlyWhenAnotherRoomIsShown() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        h.fake.setFrame(CGRect(x: 1, y: 1, width: 500, height: 500), of: a.identity)
        h.controller.palette.open(); h.controller.palette.close()
        XCTAssertEqual(h.controller.currentRoomID, id)
    }
}
