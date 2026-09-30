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

final class MeasureMinimumSizeTests: XCTestCase {
    func testMeasuresByResizingToOnePointAndRestores() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let original = CGRect(x: 120, y: 80, width: 900, height: 700)
        let w = h.window(x, id: 1, title: "A", frame: original, minimumSize: CGSize(width: 480, height: 320))
        let measured = h.controller.catalog.measureMinimumSize(of: h.controller.catalog.listWindows()![0])
        XCTAssertEqual(measured, CGSize(width: 480, height: 320))
        XCTAssertEqual(h.fake.frame(of: w.identity), original, "frame restored, window not moved")
        XCTAssertEqual(h.fake.operations, [.setSize(w.identity, CGSize(width: 1, height: 1)), .setFrame(w.identity, original)])
        XCTAssertEqual(h.fake.window(w.identity)?.title, "A", "content untouched")
    }

    func testWindowWithoutMinimumMeasuresOnePoint() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A", minimumSize: .zero)
        let measured = h.controller.catalog.measureMinimumSize(of: h.controller.catalog.listWindows()![0])
        XCTAssertEqual(measured, CGSize(width: 1, height: 1))
    }
}
