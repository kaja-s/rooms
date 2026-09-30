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

final class LayoutPreviewOverlayTests: XCTestCase {
    private func seed(_ h: Harness) -> [Room] {
        let x = h.app("x", pid: 1, name: "Xcode")
        let y = h.app("y", pid: 2, name: "Safari")
        let a = h.window(x, id: 1, title: "Main.swift", minimumSize: CGSize(width: 100, height: 100))
        let b = h.window(y, id: 2, title: "Docs", minimumSize: CGSize(width: 100, height: 100))
        let c = h.window(x, id: 3, title: "", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "Design", windows: [a, b], layout: .auto, createdAt: Date(timeIntervalSince1970: 1)),
                Room(name: "Build", windows: [c, a, b], layout: .grid, createdAt: Date(timeIntervalSince1970: 2))])
        return h.controller.rooms
    }

    func testHiddenUntilTabThenShowsOneCardPerSavedWindow() {
        let h = Harness()
        let rooms = seed(h)
        let palette = h.controller.palette
        palette.open()
        XCTAssertFalse(palette.isPreviewVisible)
        XCTAssertNil(palette.preview)
        palette.pressTab() // Auto -> Focus
        XCTAssertTrue(palette.isPreviewVisible)
        let preview = palette.preview!
        XCTAssertEqual(preview.area, h.area, "covers the visible area of the current screen")
        XCTAssertEqual(preview.layout, .focus)
        XCTAssertEqual(preview.cards.map { $0.id }, rooms[0].windows.map { $0.identity })
        XCTAssertEqual(preview.cards.map { $0.applicationName }, ["Xcode", "Safari"])
        XCTAssertEqual(preview.cards.map { $0.title }, ["Main.swift", "Docs"])
        XCTAssertTrue(preview.cards.allSatisfy { $0.icon != nil })
        XCTAssertEqual(preview.frames, LayoutEngine.frames(for: .focus, count: 2, in: h.area))
    }

    func testCardsMoveWhenCyclingAndGlideOver200ms() {
        let h = Harness()
        _ = seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.pressTab()
        let focus = palette.preview!.frames
        palette.pressTab() // Columns
        XCTAssertEqual(palette.preview?.layout, .columns)
        XCTAssertEqual(palette.preview?.frames, LayoutEngine.frames(for: .columns, count: 2, in: h.area))
        XCTAssertNotEqual(palette.preview?.frames, focus)
        palette.pressTab(shift: true)
        XCTAssertEqual(palette.preview?.frames, focus)
        XCTAssertEqual(LayoutPreview.animationDuration, 0.2)
    }

    func testArrowKeysSwitchCardsToTheSelectedRoom() {
        let h = Harness()
        let rooms = seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.pressTab()
        palette.moveSelection(by: 1)
        XCTAssertTrue(palette.isPreviewVisible)
        XCTAssertEqual(palette.preview?.cards.map { $0.id }, rooms[1].windows.map { $0.identity })
        XCTAssertEqual(palette.preview?.layout, .grid)
        XCTAssertEqual(palette.preview?.cards.map { $0.title }, ["", "Main.swift", "Docs"])
        palette.moveSelection(by: -1)
        XCTAssertEqual(palette.preview?.cards.count, 2)
    }

    func testHiddenForCreateRowAndWhenPaletteCloses() {
        let h = Harness()
        _ = seed(h)
        let palette = h.controller.palette
        palette.open()
        palette.pressTab()
        palette.query = "Something new"
        XCTAssertTrue(palette.isCreateRowSelected)
        XCTAssertNil(palette.preview)
        palette.pressEscape()
        XCTAssertFalse(palette.isPreviewVisible)
        XCTAssertNil(palette.preview)
        palette.open()
        XCTAssertFalse(palette.isPreviewVisible)
    }

    func testStaysVisibleWhileCurrentRoomWindowsMove() {
        let h = Harness()
        let rooms = seed(h)
        h.controller.showRoom(id: rooms[0].id)
        let palette = h.controller.palette
        palette.open()
        palette.pressTab()
        palette.pressTab()
        XCTAssertTrue(palette.isPreviewVisible)
        let frames = LayoutEngine.frames(for: h.controller.room(rooms[0].id)!.layout, count: 2, in: h.area)
        XCTAssertEqual(palette.preview?.frames, frames)
        XCTAssertEqual(h.fake.frame(of: rooms[0].windows[0].identity), frames[0], "real windows moved too")
    }

    func testClosedApplicationStillGetsCards() {
        let h = Harness()
        let rooms = seed(h)
        h.fake.quitApplication(processIdentifier: 2)
        h.fake.clearOperations()
        let palette = h.controller.palette
        palette.open()
        palette.pressTab()
        XCTAssertEqual(palette.preview?.cards.map { $0.id }, rooms[0].windows.map { $0.identity })
        XCTAssertTrue(h.fake.operations.isEmpty, "no window-system calls")
    }
}
