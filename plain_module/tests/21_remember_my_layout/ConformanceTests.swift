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

final class RememberMyLayoutTests: XCTestCase {
    func testUntidyArrangementBecomesMyLayoutSnappedToGrid() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 50, height: 50))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 50, height: 50))
        h.seed([Room(name: "R", windows: [a, b], layout: .auto)])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        h.fake.setFrame(CGRect(x: 13, y: 21, width: 300, height: 200), of: a.identity)
        h.fake.setFrame(CGRect(x: 322, y: 21, width: 300, height: 200), of: b.identity)
        h.controller.palette.open()
        h.controller.palette.pressCommandS()
        let room = h.controller.room(id)!
        XCTAssertEqual(room.layout, .myLayout)
        let frames = room.myLayoutFrames!
        XCTAssertEqual(frames[0], CGRect(x: 16, y: 16, width: 304, height: 208), "edges on the 16-point grid")
        XCTAssertEqual(frames[1].minX, frames[0].maxX + 8, "neighbours get exactly an 8-point gap")
        XCTAssertEqual(h.fake.frame(of: a.identity), frames[0])
        XCTAssertEqual(h.fake.frame(of: b.identity), frames[1])
        XCTAssertEqual(h.reload()[0].myLayoutFrames, frames)
        XCTAssertEqual(h.reload()[0].layout, .myLayout)
    }

    func testMyLayoutIsUsedWhenTheRoomIsShownAgain() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 50, height: 50))
        h.seed([Room(name: "R", windows: [a], layout: .auto)])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        h.fake.setFrame(CGRect(x: 200, y: 200, width: 500, height: 300), of: a.identity)
        h.controller.palette.open()
        h.controller.palette.pressCommandS()
        h.fake.setFrame(CGRect(x: 0, y: 0, width: 100, height: 100), of: a.identity)
        h.controller.showRoom(id: id)
        XCTAssertEqual(h.fake.frame(of: a.identity), CGRect(x: 208, y: 208, width: 496, height: 288))
    }
}
