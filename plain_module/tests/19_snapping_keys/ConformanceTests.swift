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

final class SnappingKeysTests: XCTestCase {
    func testHalvesAndFill() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let w = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        h.fake.focusedWindowIdentity = w.identity
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 8, y: 8, width: 708, height: 884))
        h.controller.snapKeyPressed(.right)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 724, y: 8, width: 708, height: 884))
        h.controller.snapKeyPressed(.up)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 8, y: 454, width: 1424, height: 438))
        h.controller.snapKeyPressed(.down)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 8, y: 8, width: 1424, height: 438))
        h.controller.snapKeyPressed(.fill)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 8, y: 8, width: 1424, height: 884))
    }

    func testRepeatingCyclesThirdAndTwoThirds() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let w = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        h.fake.focusedWindowIdentity = w.identity
        h.controller.snapKeyPressed(.right)
        h.controller.snapKeyPressed(.right)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 963, y: 8, width: 469, height: 884))
        h.controller.snapKeyPressed(.right)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 486, y: 8, width: 946, height: 884))
        h.controller.snapKeyPressed(.right)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 724, y: 8, width: 708, height: 884))
        h.controller.snapKeyPressed(.left)
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 8, y: 8, width: 469, height: 884))
    }

    func testCycleResetsWhenWindowLeftTheHalf() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let w = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        h.fake.focusedWindowIdentity = w.identity
        h.controller.snapKeyPressed(.left)
        h.fake.setFrame(CGRect(x: 200, y: 200, width: 300, height: 300), of: w.identity)
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: w.identity), CGRect(x: 8, y: 8, width: 708, height: 884))
    }

    func testNoFocusedWindowDoesNothing() {
        let h = Harness()
        h.controller.snapKeyPressed(.up)
        XCTAssertTrue(h.fake.operations.isEmpty)
    }
}
