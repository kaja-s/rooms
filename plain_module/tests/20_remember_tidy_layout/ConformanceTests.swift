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

final class RememberTidyLayoutTests: XCTestCase {
    private func currentRoom(_ h: Harness) -> (UUID, [AppWindow]) {
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 100, height: 100))
        let c = h.window(x, id: 3, title: "C", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "R", windows: [a, b, c], layout: .auto)])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        return (id, [a, b, c])
    }

    func testCommandSRecognizesGridWithinTolerance() {
        let h = Harness()
        let (id, windows) = currentRoom(h)
        let grid = LayoutEngine.frames(for: .grid, count: 3, in: h.area)
        h.fake.setFrame(grid[0].offsetBy(dx: 20, dy: -20), of: windows[0].identity)
        h.fake.setFrame(grid[1].insetBy(dx: 12, dy: 12), of: windows[1].identity)
        h.fake.setFrame(grid[2], of: windows[2].identity)
        let palette = h.controller.palette
        palette.open()
        palette.pressCommandS()
        XCTAssertEqual(h.controller.room(id)?.layout, .grid)
        for (i, w) in windows.enumerated() { XCTAssertEqual(h.fake.frame(of: w.identity), grid[i], "moved to the exact frames") }
        XCTAssertEqual(h.reload()[0].layout, .grid)
        XCTAssertTrue(palette.footerHints.contains("⌘S Remember mine"))
    }

    func testBeyondToleranceIsNotTidy() {
        let h = Harness()
        let (id, windows) = currentRoom(h)
        let columns = LayoutEngine.frames(for: .columns, count: 3, in: h.area)
        h.fake.setFrame(columns[0], of: windows[0].identity)
        h.fake.setFrame(columns[1].offsetBy(dx: 40, dy: 0), of: windows[1].identity)
        h.fake.setFrame(columns[2], of: windows[2].identity)
        h.controller.palette.open()
        h.controller.palette.pressCommandS()
        XCTAssertNotEqual(h.controller.room(id)?.layout, .columns)
    }

    func testDoesNothingForNonCurrentRoom() {
        let h = Harness()
        let (_, windows) = currentRoom(h)
        h.seed(h.controller.rooms + [Room(name: "Other", windows: windows, layout: .auto)])
        let palette = h.controller.palette
        palette.open()
        palette.query = "Other"
        h.fake.clearOperations()
        palette.pressCommandS()
        XCTAssertEqual(h.controller.rooms[1].layout, .auto)
        XCTAssertTrue(h.fake.operations.isEmpty)
    }
}
