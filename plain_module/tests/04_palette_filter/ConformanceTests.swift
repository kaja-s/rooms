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

final class PaletteFilterTests: XCTestCase {
    private func seed(_ h: Harness) {
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([
            Room(name: "Design", windows: [a], createdAt: Date(timeIntervalSince1970: 1)),
            Room(name: "Deep Work", windows: [a], createdAt: Date(timeIntervalSince1970: 2)),
            Room(name: "Daily Build", windows: [a], createdAt: Date(timeIntervalSince1970: 3)),
        ])
    }

    func testSubsequenceMatchIgnoringCase() {
        let h = Harness()
        seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.query = "DW"
        XCTAssertEqual(palette.rows.map { $0.title }, ["Deep Work", "Create “DW”"])
        XCTAssertEqual(palette.selectedIndex, 0)
        XCTAssertEqual(palette.selectedRoom?.name, "Deep Work")
    }

    func testOrderingPrefixThenWordStartThenRest() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([
            Room(name: "Big Bench", windows: [a], createdAt: Date(timeIntervalSince1970: 1)),
            Room(name: "Wide Bench", windows: [a], createdAt: Date(timeIntervalSince1970: 2)),
            Room(name: "Bench", windows: [a], createdAt: Date(timeIntervalSince1970: 3)),
            Room(name: "Obey Nature", windows: [a], createdAt: Date(timeIntervalSince1970: 4)),
        ])
        let palette = h.controller.palette
        palette.open()
        palette.query = "be"
        XCTAssertEqual(palette.rows.map { $0.title }, ["Bench", "Big Bench", "Wide Bench", "Obey Nature", "Create “be”"])
    }

    func testCreateRowRules() {
        let h = Harness()
        seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.query = "design"
        XCTAssertEqual(palette.rows.map { $0.title }, ["Design"], "exact name (ignoring case) has no Create row")
        palette.query = "zzz"
        XCTAssertEqual(palette.rows, [.create(name: "zzz")])
        XCTAssertTrue(palette.isCreateRowSelected, "selected when there are no matches")
        palette.query = ""
        XCTAssertEqual(palette.rows.count, 3)
    }

    func testAcceptanceTypingDe() {
        let h = Harness()
        seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.query = "de"
        XCTAssertEqual(palette.rows.map { $0.title }, ["Design", "Deep Work", "Create “de”"])
        XCTAssertFalse(palette.rows.map { $0.title }.contains("Daily Build"))
        XCTAssertEqual(palette.selectedRoom?.name, "Design")
    }
}
