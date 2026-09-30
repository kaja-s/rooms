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

final class TabCyclesLayoutsTests: XCTestCase {
    private func seedRoom(_ h: Harness, minWidth: CGFloat = 100, frames: [CGRect]? = nil) -> UUID {
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: minWidth, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: minWidth, height: 100))
        let c = h.window(x, id: 3, title: "C", minimumSize: CGSize(width: minWidth, height: 100))
        h.seed([Room(name: "R", windows: [a, b, c], layout: .auto, myLayoutFrames: frames)])
        return h.controller.rooms[0].id
    }

    func testAcceptanceCycleAndPersistence() {
        let h = Harness()
        let id = seedRoom(h)
        let palette = h.controller.palette
        palette.open()
        var seen: [Layout] = []
        for _ in 0..<5 {
            palette.pressTab()
            seen.append(h.controller.room(id)!.layout)
            XCTAssertEqual(h.reload()[0].layout, h.controller.room(id)!.layout, "written to disk at once")
        }
        XCTAssertEqual(seen, [.focus, .columns, .grid, .stack, .auto])
        palette.pressTab(shift: true)
        XCTAssertEqual(h.controller.room(id)!.layout, .stack)
        XCTAssertEqual(h.reload()[0].layout, .stack)
    }

    func testAcceptanceNonFittingLayoutsAreStillOffered() {
        let h = Harness()
        _ = seedRoom(h, minWidth: 1000)
        let palette = h.controller.palette
        palette.open()
        var seen: [Layout] = []
        for _ in 0..<4 { palette.pressTab(); seen.append(h.controller.rooms[0].layout) }
        XCTAssertEqual(seen, [.focus, .columns, .grid, .stack])
        palette.pressTab(); XCTAssertEqual(h.controller.rooms[0].layout, .auto, "My Layout skipped without frames")
        palette.pressTab(shift: true); XCTAssertEqual(h.controller.rooms[0].layout, .stack)
    }

    func testNonFittingLayoutStillMovesCurrentRoomWindows() {
        let h = Harness()
        let id = seedRoom(h, minWidth: 1000)
        h.controller.showRoom(id: id)
        let palette = h.controller.palette
        palette.open()
        palette.pressTab(); palette.pressTab()
        XCTAssertEqual(h.controller.rooms[0].layout, .columns)
        let columns = LayoutEngine.frames(for: .columns, count: 3, in: h.area)
        let requested = h.fake.operations.compactMap { op -> CGRect? in if case .setFrame(_, let f) = op { return f } else { return nil } }
        XCTAssertTrue(columns.allSatisfy { requested.contains($0) }, "each window is asked to take its Columns frame")
    }

    func testMyLayoutIsOfferedWhenFramesExist() {
        let h = Harness()
        let frames = [CGRect(x: 8, y: 8, width: 400, height: 400), CGRect(x: 420, y: 8, width: 400, height: 400), CGRect(x: 840, y: 8, width: 400, height: 400)]
        _ = seedRoom(h, frames: frames)
        let palette = h.controller.palette
        palette.open()
        for _ in 0..<4 { palette.pressTab() }
        XCTAssertEqual(h.controller.rooms[0].layout, .myLayout)
    }

    func testCurrentRoomWindowsMoveAtOnce() {
        let h = Harness()
        let id = seedRoom(h)
        h.controller.showRoom(id: id)
        let palette = h.controller.palette
        palette.open()
        palette.pressTab() // Focus
        palette.pressTab() // Columns
        let columns = LayoutEngine.frames(for: .columns, count: 3, in: h.area)
        for (i, window) in h.controller.rooms[0].windows.enumerated() {
            XCTAssertEqual(h.fake.frame(of: window.identity), columns[i])
        }
    }

    func testFooterShowsHereAndTabHint() {
        let h = Harness()
        _ = seedRoom(h)
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.hereText, "Here: Focus", "Auto resolved to the layout that fits")
        XCTAssertTrue(palette.footerHints.contains("⇥ Layout"))
        palette.pressTab(); palette.pressTab()
        XCTAssertEqual(palette.hereText, "Here: Columns")
    }
}
