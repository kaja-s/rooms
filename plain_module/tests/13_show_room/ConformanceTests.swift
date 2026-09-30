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

final class ShowRoomTests: XCTestCase {
    func testReturnOnRowShowsRoomAndClosesPalette() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B", minimized: true)
        let c = h.window(x, id: 3, title: "C")
        h.seed([Room(name: "R", windows: [a, b, c], layout: .focus)])
        let palette = h.controller.palette
        palette.open()
        palette.pressReturn()
        XCTAssertFalse(palette.isVisible)
        let frames = LayoutEngine.frames(for: .focus, count: 3, in: h.area)
        XCTAssertEqual(h.fake.frame(of: a.identity), frames[0])
        XCTAssertEqual(h.fake.frame(of: b.identity), frames[1])
        XCTAssertEqual(h.fake.frame(of: c.identity), frames[2])
        XCTAssertFalse(h.fake.window(b.identity)!.isMinimized)
        XCTAssertEqual(h.fake.raiseOrder.last, a.identity)
        XCTAssertEqual(h.fake.focusedByOperation, a.identity)
    }

    func testAcceptanceFocusRoomThreeWindows() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B", minimized: true)
        let c = h.window(x, id: 3, title: "C")
        h.seed([Room(name: "R", windows: [a, b, c], layout: .focus)])
        h.controller.palette.open()
        h.controller.palette.clickRow(0)
        XCTAssertEqual(h.fake.frame(of: a.identity), CGRect(x: 8, y: 8, width: 944, height: 884))
        XCTAssertEqual(h.fake.frame(of: b.identity), CGRect(x: 960, y: 454, width: 472, height: 438))
        XCTAssertEqual(h.fake.frame(of: c.identity), CGRect(x: 960, y: 8, width: 472, height: 438))
        XCTAssertTrue(h.fake.operations.contains(.unminimize(b.identity)))
        XCTAssertEqual(h.fake.raiseOrder.last, a.identity)
        XCTAssertEqual(h.fake.focusedWindowIdentity, a.identity)
    }

    func testMissingWindowsAreSkippedAndFirstFoundGetsFocus() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let main = h.window(y, id: 9, title: "Main")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.seed([Room(name: "R", windows: [main, a, b], layout: .columns)])
        h.fake.quitApplication(processIdentifier: 2)
        h.controller.showRoom(id: h.controller.rooms[0].id)
        let frames = LayoutEngine.frames(for: .columns, count: 2, in: h.area)
        XCTAssertEqual(h.fake.frame(of: a.identity), frames[0])
        XCTAssertEqual(h.fake.frame(of: b.identity), frames[1])
        XCTAssertEqual(h.fake.focusedByOperation, a.identity)
    }

    func testAutoAndMyLayoutAreResolved() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 1000, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 1000, height: 100))
        h.seed([Room(name: "Auto", windows: [a, b], layout: .auto),
                Room(name: "Mine", windows: [a, b], layout: .myLayout, myLayoutFrames: [CGRect(x: 8, y: 400, width: 1100, height: 400), CGRect(x: 8, y: 8, width: 1200, height: 380)])])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.frames(for: .stack, count: 2, in: h.area)[0])
        h.controller.showRoom(id: h.controller.rooms[1].id)
        XCTAssertEqual(h.fake.frame(of: a.identity), CGRect(x: 8, y: 400, width: 1100, height: 400))
        XCTAssertEqual(h.fake.frame(of: b.identity), CGRect(x: 8, y: 8, width: 1200, height: 380))
    }

    func testAcceptanceQuitApplicationShowsNotification() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Ghost Town", windows: [a])])
        h.fake.quitApplication(processIdentifier: 1)
        h.app("y", pid: 2, name: "Y")
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.controller.notificationMessage, "None of the windows in “Ghost Town” are open")
        XCTAssertTrue(h.fake.operations.isEmpty, "nothing moved or hidden")
    }
}
