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

final class NewRoomShownAfterCreateTests: XCTestCase {
    func testCreatedRoomIsShownImmediately() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.window(y, id: 3, title: "Other")
        h.controller.beginCreateRoom(named: "Fresh")
        h.controller.picker.toggleCard(at: 0); h.controller.picker.toggleCard(at: 1)
        h.controller.picker.confirm()
        let room = h.controller.rooms[0]
        XCTAssertEqual(h.controller.currentRoomID, room.id)
        XCTAssertNotNil(room.lastShown)
        let frames = LayoutEngine.frames(for: .focus, count: 2, in: h.area)
        XCTAssertEqual(h.fake.frame(of: a.identity), frames[0])
        XCTAssertEqual(h.fake.frame(of: b.identity), frames[1])
        XCTAssertTrue(h.fake.isHidden(application: 2))
        XCTAssertEqual(h.fake.focusedByOperation, a.identity)
    }
}
