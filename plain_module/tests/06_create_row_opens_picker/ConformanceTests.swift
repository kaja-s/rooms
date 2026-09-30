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

final class CreateRowOpensPickerTests: XCTestCase {
    func testReturnOnCreateRowOpensPicker() {
        let h = Harness()
        h.fake.visibleArea = CGRect(x: 100, y: 50, width: 1200, height: 800)
        let x = h.app("x", pid: 1, name: "Xcode")
        h.window(x, id: 1, title: "Main.swift")
        h.window(x, id: 2, title: "")
        let palette = h.controller.palette
        palette.open()
        palette.query = "Alpha"
        palette.pressReturn()
        XCTAssertFalse(palette.isVisible)
        let picker = h.controller.picker
        XCTAssertTrue(picker.isPresented)
        XCTAssertEqual(picker.mode, .create(name: "Alpha"))
        XCTAssertEqual(picker.title, "Choose the windows for “Alpha”")
        XCTAssertEqual(picker.screenArea, h.fake.visibleArea)
        XCTAssertEqual(picker.cards.map { $0.title }, ["Main.swift", "Xcode"], "title falls back to the application name")
        XCTAssertEqual(picker.cards.map { $0.applicationName }, ["Xcode", "Xcode"])
        XCTAssertTrue(picker.cards.allSatisfy { $0.snapshot != nil && $0.icon != nil })
        XCTAssertFalse(picker.showsAppIconInsteadOfSnapshot)
        XCTAssertEqual(picker.cancelButtonTitle, "Cancel")
        XCTAssertEqual(picker.primaryButtonTitle, "Create Room")
    }

    func testWithoutScreenRecordingCardsShowTheIcon() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A")
        h.fake.screenRecordingPermission = false
        h.controller.beginCreateRoom(named: "R")
        XCTAssertTrue(h.controller.picker.showsAppIconInsteadOfSnapshot)
        XCTAssertNil(h.controller.picker.cards[0].snapshot)
        XCTAssertNotNil(h.controller.picker.cards[0].icon)
    }

    func testCancelClosesWithoutSaving() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A")
        h.controller.beginCreateRoom(named: "R")
        h.controller.picker.toggleCard(at: 0)
        h.controller.picker.cancel()
        XCTAssertFalse(h.controller.picker.isPresented)
        XCTAssertTrue(h.controller.rooms.isEmpty)
        XCTAssertTrue(h.reload().isEmpty)
    }
}
