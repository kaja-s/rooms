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

final class AutoResolutionTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func windows(_ n: Int, minWidth: CGFloat, minHeight: CGFloat = 100) -> [AppWindow] {
        (0..<n).map { AppWindow(identity: WindowIdentity(bundleIdentifier: "a", processIdentifier: 1, windowID: UInt32($0)), applicationName: "A", title: "", frame: .zero, minimumSize: CGSize(width: minWidth, height: minHeight)) }
    }

    func testAcceptanceMinWidth400ResolvesToFocus() {
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(3, minWidth: 400), in: area), .focus)
    }

    func testAcceptanceMinWidth1000ResolvesToStack() {
        let w = windows(3, minWidth: 1000)
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: w, in: area), .stack)
        for layout in [Layout.focus, .columns, .grid] {
            let narrowest = LayoutEngine.frames(for: layout, count: 3, in: area).map { $0.width }.min()!
            XCTAssertLessThan(narrowest, 1000, "\(layout.displayName) leaves a frame narrower than 1000")
        }
    }

    func testOrderFocusColumnsGrid() {
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(3, minWidth: 600), in: area), .grid)
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(2, minWidth: 600, minHeight: 800), in: area), .columns)
    }

    func testLegacyMyLayoutLoadsAsAuto() throws {
        let json = #"[{"id":"BC800FEA-A050-4A1B-88BE-8480B1164654","name":"test","windows":[],"layout":"myLayout","myLayoutFrames":[[[0,0],[10,10]]],"createdAt":"2026-09-30T12:58:16Z"}]"#
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let rooms = RoomStore(fileURL: url).load()
        XCTAssertEqual(rooms.map { $0.name }, ["test"])
        XCTAssertEqual(rooms.first?.layout, .auto)
    }

    func testConcreteLayoutsResolveToThemselves() {
        for layout in [Layout.focus, .columns, .grid, .stack] {
            XCTAssertEqual(LayoutEngine.resolve(layout, windows: windows(3, minWidth: 5000), in: area), layout)
        }
    }
}
