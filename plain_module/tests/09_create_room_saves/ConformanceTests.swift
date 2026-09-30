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

final class CreateRoomSavesTests: XCTestCase {
    func testCreateRoomSavesInPlaceOrderWithAutoLayout() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 300, height: 200))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 410, height: 310))
        let c = h.window(x, id: 3, title: "C", minimumSize: CGSize(width: 520, height: 420))
        h.controller.beginCreateRoom(named: "Build")
        let picker = h.controller.picker
        picker.toggleCard(at: 1); picker.toggleCard(at: 0); picker.toggleCard(at: 2) // B, A, C
        picker.confirm()
        XCTAssertFalse(picker.isPresented)
        XCTAssertEqual(h.controller.rooms.count, 1)
        let room = h.controller.rooms[0]
        XCTAssertEqual(room.name, "Build")
        XCTAssertEqual(room.windows.map { $0.identity }, [b.identity, a.identity, c.identity])
        XCTAssertEqual(room.layout, .auto)
        XCTAssertNil(room.directKey)
        XCTAssertEqual(room.windows.map { $0.minimumSize }, [CGSize(width: 410, height: 310), CGSize(width: 300, height: 200), CGSize(width: 520, height: 420)])
        // Minimum sizes were measured before saving: each window was resized to 1x1 and restored.
        XCTAssertTrue(h.fake.operations.contains(.setSize(a.identity, CGSize(width: 1, height: 1))))
        let reloaded = h.reload()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].windows.map { $0.identity }, [b.identity, a.identity, c.identity])
        XCTAssertEqual(reloaded[0].layout, .auto)
        XCTAssertNil(reloaded[0].directKey)
    }

    func testRoomListIsAppended() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "First", windows: [a])])
        h.controller.beginCreateRoom(named: "Second")
        h.controller.picker.toggleCard(at: 0)
        h.controller.picker.confirm()
        XCTAssertEqual(h.reload().map { $0.name }, ["First", "Second"])
    }
}
