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

final class GettingStartedTests: XCTestCase {
    func testOpensFromMenuWithStepsAndDone() {
        let h = Harness()
        h.fake.visibleArea = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let model = h.controller.gettingStarted
        XCTAssertFalse(model.isPresented)
        h.controller.statusMenu.perform(.gettingStarted)
        XCTAssertTrue(model.isPresented)
        XCTAssertEqual(model.screenArea, h.fake.visibleArea, "centered on the current screen")
        XCTAssertEqual(model.title, "Getting Started")
        XCTAssertEqual(model.steps.count, 4)
        XCTAssertEqual(model.steps[0], "Open the windows a project needs.")
        XCTAssertEqual(model.steps[1], "Press ⌥Space, type a name for the room, and press ↵.")
        XCTAssertEqual(model.steps[2], "Click the windows that belong in it; the number on a card is its place, and 1 is the main window. Then Create Room.")
        XCTAssertEqual(model.steps[3], "Press ⇥ in ⌥Space to change the layout.")
        XCTAssertEqual(model.footerText, "From then on, ⌥Space and the room's name, or ⌃⌥1–9, brings it back.")
        XCTAssertEqual(model.doneButtonTitle, "Done")
        model.done()
        XCTAssertFalse(model.isPresented)
    }

    func testOpensOnFirstLaunchOnly() {
        let h = Harness(firstLaunch: true)
        XCTAssertTrue(h.controller.gettingStarted.isPresented)
        XCTAssertTrue(h.defaults.bool(forKey: "hasLaunchedBefore"))
        h.controller.gettingStarted.done()
        let second = AppController(store: h.store, windowSystem: h.fake, defaults: h.defaults)
        second.start()
        XCTAssertFalse(second.gettingStarted.isPresented)
    }
}
