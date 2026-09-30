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

final class LayoutPreviewTests: XCTestCase {
    func testPreviewMatchesEngineFrames() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "R", windows: [a, b], layout: .grid)])
        let palette = h.controller.palette
        palette.open()
        let preview = palette.preview
        XCTAssertEqual(preview?.area, h.area)
        XCTAssertEqual(preview?.layout, .grid)
        XCTAssertEqual(preview?.frames, LayoutEngine.frames(for: .grid, count: 2, in: h.area))
        XCTAssertEqual(preview?.frames.count, 2, "one rectangle per window, labeled by place number")
    }

    func testPreviewChangesWithLayoutAndAnimates() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "R", windows: [a, b], layout: .auto)])
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.preview?.layout, .focus, "Auto shows the resolved layout")
        palette.pressTab(); palette.pressTab()
        XCTAssertEqual(palette.preview?.layout, .columns)
        XCTAssertEqual(LayoutPreview.animationDuration, 0.2)
    }

    func testPreviewHiddenForCreateRow() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "R", windows: [a])])
        let palette = h.controller.palette
        palette.open()
        XCTAssertNotNil(palette.preview)
        palette.query = "Something new"
        XCTAssertTrue(palette.isCreateRowSelected)
        XCTAssertNil(palette.preview)
    }
}
