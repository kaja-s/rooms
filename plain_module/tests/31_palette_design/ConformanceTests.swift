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

final class PaletteDesignTests: XCTestCase {
    func testDesignValues() {
        XCTAssertEqual(PaletteDesign.panelWidth, 640)
        XCTAssertEqual(PaletteDesign.panelCornerRadius, 22)
        XCTAssertEqual(PaletteDesign.rowHeight, 64)
        XCTAssertEqual(PaletteDesign.selectionHex, "#3B76F6")
        XCTAssertEqual(PaletteDesign.onSelectionHex, "#FFFFFF")
    }

    func testSelectedRowShowsTrailerReturnAndDelete() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a], directKey: 1, createdAt: Date(timeIntervalSince1970: 1)),
                Room(name: "Build", windows: [a], directKey: 2, createdAt: Date(timeIntervalSince1970: 2)),
                Room(name: "Morning", windows: [a], createdAt: Date(timeIntervalSince1970: 3))])
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.rowTrailingElements(at: 0), ["⌃⌥1", "↵", "ⓧ"])
        XCTAssertEqual(palette.rowTrailingElements(at: 1), ["⌃⌥2"])
        XCTAssertEqual(palette.rowTrailingElements(at: 2), ["⌃⌥3"])
        palette.moveSelection(by: 2)
        XCTAssertEqual(palette.rowTrailingElements(at: 2), ["⌃⌥3", "↵", "ⓧ"])
        XCTAssertEqual(palette.rowTrailingElements(at: 0), ["⌃⌥1"])
    }

    func testCurrentRoomTrailer() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Deep Work", windows: [a], directKey: 4), Room(name: "Other", windows: [a])])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.rowTrailingElements(at: 0), ["Current", "↵", "ⓧ"])
        palette.moveSelection(by: 1)
        XCTAssertEqual(palette.rowTrailingElements(at: 0), ["Current"])
    }

    func testNothingBetweenListAndKeyHints() {
        XCTAssertEqual(PaletteDesign.sections, [.searchField, .divider, .list, .keyHints])
        let list = PaletteDesign.sections.firstIndex(of: .list)!
        XCTAssertEqual(PaletteDesign.sections[list + 1], .keyHints)
    }

    private func rooms(_ names: [String], in h: Harness) -> [Room] {
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        return names.enumerated().map { i, name in
            Room(name: name, windows: [a], createdAt: Date(timeIntervalSince1970: Double(i + 1)))
        }
    }

    func testHeightWithOneRoom() {
        let h = Harness()
        h.seed(rooms(["alpha"], in: h))
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.rows.count, 1)
        XCTAssertEqual(palette.panelHeight, 213)
    }

    func testHeightWithThreeAndNineRooms() {
        let h = Harness()
        h.seed(rooms(["r1", "r2", "r3"], in: h))
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.panelHeight, 349)

        let h9 = Harness()
        h9.seed(rooms((1...9).map { "room \($0)" }, in: h9))
        h9.controller.palette.open()
        XCTAssertEqual(h9.controller.palette.rows.count, 9)
        XCTAssertEqual(h9.controller.palette.panelHeight, 757)
    }

    func testHeightFollowsTyping() {
        let h = Harness()
        h.seed(rooms(["alpha"], in: h))
        let palette = h.controller.palette
        palette.open()
        palette.query = "zz"
        XCTAssertEqual(palette.rows, [.create(name: "zz")])
        XCTAssertEqual(palette.panelHeight, 213)
        palette.query = "a"
        XCTAssertEqual(palette.rows.count, 2)
        XCTAssertEqual(palette.rows.last, .create(name: "a"))
        XCTAssertEqual(palette.panelHeight, 281)
    }

    func testHeightOfEmptyState() {
        let h = Harness()
        let palette = h.controller.palette
        palette.open()
        XCTAssertNotNil(palette.emptyStateText)
        XCTAssertEqual(palette.panelHeight, 213)
    }

    func testHeightFormulaHasNoMinimum() {
        for n in 1...9 {
            XCTAssertEqual(PaletteDesign.panelHeight(rowCount: n), CGFloat(149 + 64 * n + 4 * (n - 1)))
        }
        XCTAssertEqual(PaletteDesign.panelHeight(rowCount: 0), 213)
    }
}
