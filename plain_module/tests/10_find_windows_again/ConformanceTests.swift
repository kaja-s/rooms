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

final class FindWindowsAgainTests: XCTestCase {
    func testIdentityThenTitleThenFirstUnmatched() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let saved1 = h.window(x, id: 1, title: "One")
        let saved2 = h.window(x, id: 2, title: "Two")
        let saved3 = h.window(x, id: 3, title: "Three")
        // Relaunch: new pid and window ids; titles partly changed.
        h.fake.quitApplication(processIdentifier: 1)
        let relaunched = h.app("x", pid: 9, name: "X")
        let newTwo = h.window(relaunched, id: 21, title: "Two")
        let newOther = h.window(relaunched, id: 22, title: "Other")
        let newThird = h.window(relaunched, id: 23, title: "Changed")
        let found = h.controller.catalog.find([saved1, saved2, saved3])
        XCTAssertEqual(found[1]?.identity, newTwo.identity, "found by title")
        XCTAssertEqual(found[0]?.identity, newOther.identity, "first unmatched window of the same application")
        XCTAssertEqual(found[2]?.identity, newThird.identity, "each window matched at most once")
    }

    func testAcceptanceRelaunchedApplication() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let saved = h.window(x, id: 1, title: "Notes")
        h.fake.quitApplication(processIdentifier: 1)
        let relaunched = h.app("x", pid: 2, name: "X")
        h.window(relaunched, id: 5, title: "Other")
        let byTitle = h.window(relaunched, id: 6, title: "Notes")
        XCTAssertEqual(h.controller.catalog.find([saved])[0]?.identity, byTitle.identity)

        let a = h.window(relaunched, id: 7, title: "A")
        let b = h.window(relaunched, id: 8, title: "B")
        h.fake.quitApplication(processIdentifier: 2)
        let again = h.app("x", pid: 3, name: "X")
        let r1 = h.window(again, id: 9, title: "Renamed 1")
        let r2 = h.window(again, id: 10, title: "Renamed 2")
        let found = h.controller.catalog.find([a, b])
        XCTAssertEqual(found.map { $0?.identity }, [r1.identity, r2.identity])
    }

    func testNotRunningIsNotFound() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let saved = h.window(x, id: 1, title: "One")
        h.fake.quitApplication(processIdentifier: 1)
        let y = h.app("y", pid: 2, name: "Y")
        h.window(y, id: 1, title: "One")
        XCTAssertEqual(h.controller.catalog.find([saved]), [nil])
    }

    func testExactIdentityWinsOverTitle() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let saved = h.window(x, id: 1, title: "Same")
        h.window(x, id: 2, title: "Same")
        h.fake.windows[0].title = "Renamed"
        XCTAssertEqual(h.controller.catalog.find([saved])[0]?.identity, saved.identity)
    }
}
