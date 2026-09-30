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

final class LayoutEngineFramesTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func windows(_ n: Int, min: CGSize) -> [AppWindow] {
        (0..<n).map { AppWindow(identity: WindowIdentity(bundleIdentifier: "a", processIdentifier: 1, windowID: UInt32($0)), applicationName: "A", title: "", frame: .zero, minimumSize: min) }
    }

    func testGapsAndFocusSingleWindow() {
        XCTAssertEqual(LayoutEngine.gap, 8)
        XCTAssertEqual(LayoutEngine.frames(for: .focus, count: 1, in: area), [CGRect(x: 8, y: 8, width: 1424, height: 884)])
    }

    func testFocusMainLeftTwoThirdsOthersStackedRight() {
        let f = LayoutEngine.frames(for: .focus, count: 3, in: area)
        XCTAssertEqual(f[0], CGRect(x: 8, y: 8, width: 944, height: 884))
        XCTAssertEqual(f[1], CGRect(x: 960, y: 454, width: 472, height: 438))
        XCTAssertEqual(f[2], CGRect(x: 960, y: 8, width: 472, height: 438))
        XCTAssertEqual(f[1].minX - f[0].maxX, 8)
        XCTAssertEqual(f[1].minY - f[2].maxY, 8)
        XCTAssertTrue(f[1].maxY > f[2].maxY, "top to bottom")
    }

    func testColumnsEqualWidthsFullHeight() {
        let f = LayoutEngine.frames(for: .columns, count: 4, in: area)
        XCTAssertEqual(Set(f.map { $0.width }).count, 1)
        XCTAssertEqual(Set(f.map { $0.height }), [884])
        for i in 1..<4 { XCTAssertEqual(f[i].minX - f[i - 1].maxX, 8) }
        XCTAssertEqual(f[0].minX, 8)
    }

    func testGridAsSquareAsPossible() {
        let f = LayoutEngine.frames(for: .grid, count: 5, in: area)
        XCTAssertEqual(f.count, 5)
        XCTAssertEqual(Set(f.map { $0.width }).count, 1)
        XCTAssertEqual(f[0].minY, f[1].minY, "row 0 left to right")
        XCTAssertEqual(f[2].minY, f[0].minY)
        XCTAssertTrue(f[3].maxY < f[0].minY, "row 1 below row 0")
        XCTAssertEqual(f[3].minX, f[0].minX)
    }

    func testStackOffsets() {
        let f = LayoutEngine.frames(for: .stack, count: 3, in: area)
        XCTAssertEqual(f[0], CGRect(x: 8, y: 8, width: 1424, height: 884))
        XCTAssertEqual(f[1].minX, f[0].minX + 32)
        XCTAssertEqual(f[1].maxY, f[0].maxY - 32)
        XCTAssertEqual(f[1].width, f[0].width - 32)
        XCTAssertEqual(f[1].height, f[0].height - 32)
        XCTAssertEqual(f[2].minX, 72)
    }

    func testFitsAndStackAlwaysFits() {
        XCTAssertTrue(LayoutEngine.fits(.focus, windows: windows(3, min: CGSize(width: 400, height: 400)), in: area))
        XCTAssertFalse(LayoutEngine.fits(.focus, windows: windows(3, min: CGSize(width: 400, height: 500)), in: area))
        XCTAssertFalse(LayoutEngine.fits(.grid, windows: windows(3, min: CGSize(width: 800, height: 100)), in: area))
        XCTAssertTrue(LayoutEngine.fits(.stack, windows: windows(3, min: CGSize(width: 5000, height: 5000)), in: area))
    }

    func testFramesAreWholePoints() {
        let odd = CGRect(x: 0.4, y: 0.6, width: 1333, height: 777)
        for layout in [Layout.focus, .columns, .grid, .stack] {
            for frame in LayoutEngine.frames(for: layout, count: 3, in: odd) {
                XCTAssertEqual(frame, frame.integral)
            }
        }
    }
}
