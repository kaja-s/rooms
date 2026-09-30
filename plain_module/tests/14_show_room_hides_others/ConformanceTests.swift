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

final class ShowRoomHidesOthersTests: XCTestCase {
    func testAcceptanceRoundTrip() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let x1 = h.window(x, id: 1, title: "X1")
        let x2 = h.window(x, id: 2, title: "X2")
        let x3 = h.window(x, id: 3, title: "X3")
        let y4 = h.window(y, id: 4, title: "Y4")
        h.seed([Room(name: "A", windows: [x1, x2]), Room(name: "B", windows: [x3, y4])])
        let countBefore = h.fake.windows.count

        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertTrue(h.fake.isHidden(application: 2), "application with no window in the room is hidden")
        XCTAssertTrue(h.fake.window(x3.identity)!.isMinimized, "other window of an application in the room is minimized")
        XCTAssertFalse(h.fake.window(x1.identity)!.isMinimized)
        XCTAssertFalse(h.fake.isHidden(application: 1))

        h.controller.showRoom(id: h.controller.rooms[1].id)
        XCTAssertFalse(h.fake.isHidden(application: 2))
        XCTAssertFalse(h.fake.window(x3.identity)!.isMinimized)
        XCTAssertFalse(h.fake.window(y4.identity)!.isMinimized)
        XCTAssertTrue(h.fake.window(x1.identity)!.isMinimized)
        XCTAssertTrue(h.fake.window(x2.identity)!.isMinimized)
        XCTAssertEqual(h.fake.windows.count, countBefore, "no window is closed")
    }

    func testHiddenApplicationOfTheRoomIsUnhidden() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.fake.setHidden(true, application: 1)
        h.seed([Room(name: "R", windows: [a])])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertFalse(h.fake.isHidden(application: 1))
    }
}
