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

final class PaletteRowsTests: XCTestCase {
    private func rooms(_ h: Harness) -> [Room] {
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(y, id: 2, title: "B")
        let c = h.window(x, id: 3, title: "C")
        h.seed([
            Room(name: "Never A", windows: [a], layout: .auto, createdAt: Date(timeIntervalSince1970: 10)),
            Room(name: "Shown Old", windows: [a, b], layout: .grid, createdAt: Date(timeIntervalSince1970: 5), lastShown: Date(timeIntervalSince1970: 100)),
            Room(name: "Never B", windows: [c, a, b], layout: .focus, directKey: 4, createdAt: Date(timeIntervalSince1970: 20)),
            Room(name: "Shown New", windows: [c], layout: .stack, createdAt: Date(timeIntervalSince1970: 1), lastShown: Date(timeIntervalSince1970: 200)),
        ])
        return h.controller.rooms
    }

    func testOrderMostRecentlyShownThenCreationOrder() {
        let h = Harness()
        _ = rooms(h)
        h.controller.palette.open()
        XCTAssertEqual(h.controller.palette.rows.map { $0.title }, ["Shown New", "Shown Old", "Never A", "Never B"])
    }

    func testRowContent() {
        let h = Harness()
        _ = rooms(h)
        h.controller.palette.open()
        guard case .room(let row) = h.controller.palette.rows[3] else { return XCTFail("expected room row") }
        XCTAssertEqual(row.name, "Never B")
        XCTAssertEqual(row.subtitle, "Focus · 3 windows")
        XCTAssertEqual(row.icons.count, 3)
        XCTAssertTrue(row.icons.allSatisfy { $0 != nil })
        XCTAssertEqual(row.trailer, "⌃⌥4")
        guard case .room(let plain) = h.controller.palette.rows[2] else { return XCTFail("expected room row") }
        XCTAssertEqual(plain.trailer, "⌃⌥3", "rooms are numbered automatically")
    }

    func testCurrentWinsOverDirectKey() {
        let h = Harness()
        let list = rooms(h)
        h.controller.showRoom(id: list[2].id) // Never B, has key 4
        h.controller.palette.open()
        guard case .room(let row) = h.controller.palette.rows[0] else { return XCTFail("expected room row") }
        XCTAssertEqual(row.name, "Never B")
        XCTAssertEqual(row.trailer, "Current")
        XCTAssertTrue(row.isCurrent)
    }

    func testFirstRowSelectedAndArrowKeysMove() {
        let h = Harness()
        _ = rooms(h)
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.selectedIndex, 0)
        palette.moveSelection(by: 1)
        palette.moveSelection(by: 1)
        XCTAssertEqual(palette.selectedIndex, 2)
        palette.moveSelection(by: -1)
        XCTAssertEqual(palette.selectedIndex, 1)
        palette.moveSelection(by: -5)
        XCTAssertEqual(palette.selectedIndex, 0)
        palette.moveSelection(by: 9)
        XCTAssertEqual(palette.selectedIndex, 3)
    }

    func testEmptyState() {
        let h = Harness()
        let palette = h.controller.palette
        palette.open()
        XCTAssertTrue(palette.rows.isEmpty)
        XCTAssertEqual(palette.emptyStateText, "No rooms yet. Type a name and press ↵ to create one.")
        palette.query = "x"
        XCTAssertNil(palette.emptyStateText, "not shown while text is typed")
    }
}
