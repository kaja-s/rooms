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

final class EditWindowsTests: XCTestCase {
    func testPickerOpensInEditModeWithFoundWindowsPreselected() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        let c = h.window(x, id: 3, title: "C")
        let gone = AppWindow(identity: WindowIdentity(bundleIdentifier: "z", processIdentifier: 9, windowID: 1), applicationName: "Z", title: "Z", frame: .zero)
        h.seed([Room(name: "Design", windows: [b, gone, a])])
        let id = h.controller.rooms[0].id
        let palette = h.controller.palette
        palette.open()
        palette.performContextMenu(.editWindows, onRow: 0)
        XCTAssertFalse(palette.isVisible)
        let picker = h.controller.picker
        XCTAssertTrue(picker.isPresented)
        XCTAssertEqual(picker.mode, .edit(roomID: id))
        XCTAssertEqual(picker.title, "Edit the windows of “Design”")
        XCTAssertEqual(picker.primaryButtonTitle, "Save Room")
        XCTAssertEqual(picker.cards.map { $0.title }, ["A", "B", "C"])
        XCTAssertEqual(picker.cards.map { $0.badge }, [2, 1, nil], "found windows preselected in room order; missing window left out")
        picker.cancel()
        XCTAssertEqual(h.controller.rooms[0].windows.count, 3, "cancel changes nothing")
    }

    func testFromStatusMenuForCurrentRoom() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a])])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        h.controller.statusMenu.perform(.editWindows)
        XCTAssertEqual(h.controller.picker.mode, .edit(roomID: h.controller.rooms[0].id))
    }

    func testRemoveAndReappendThenSave() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 111, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 222, height: 100))
        let c = h.window(x, id: 3, title: "C", minimumSize: CGSize(width: 333, height: 100))
        h.seed([Room(name: "Design", windows: [a, b], layout: .myLayout, myLayoutFrames: [CGRect(x: 8, y: 8, width: 500, height: 500), CGRect(x: 520, y: 8, width: 500, height: 500)])])
        let id = h.controller.rooms[0].id
        h.controller.beginEditWindows(ofRoom: id)
        let picker = h.controller.picker
        picker.toggleCard(at: 0) // remove A
        XCTAssertEqual(picker.cards.map { $0.badge }, [nil, 1, nil])
        picker.toggleCard(at: 0) // A goes to the end
        XCTAssertEqual(picker.cards.map { $0.badge }, [2, 1, nil])
        picker.confirm()
        XCTAssertFalse(picker.isPresented)
        var room = h.controller.room(id)!
        XCTAssertEqual(room.windows.map { $0.title }, ["B", "A"])
        XCTAssertEqual(room.windows.map { $0.minimumSize.width }, [222, 111], "minimum sizes measured again")
        XCTAssertNotNil(room.myLayoutFrames, "same set of windows keeps My Layout frames")
        h.controller.beginEditWindows(ofRoom: id)
        h.controller.picker.toggleCard(at: 2) // add C
        h.controller.picker.confirm()
        room = h.controller.room(id)!
        XCTAssertEqual(room.windows.map { $0.title }, ["B", "A", "C"])
        XCTAssertNil(room.myLayoutFrames, "changed set drops My Layout frames")
        XCTAssertEqual(h.reload()[0].windows.map { $0.title }, ["B", "A", "C"])
        XCTAssertEqual(h.reload()[0].windows.map { $0.minimumSize.width }, [222, 111, 333])
    }

    func testCurrentRoomIsShownAgainAfterSaving() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.seed([Room(name: "Design", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        XCTAssertTrue(h.fake.window(b.identity)!.isMinimized)
        h.controller.beginEditWindows(ofRoom: id)
        h.controller.picker.toggleCard(at: 1)
        h.controller.picker.confirm()
        XCTAssertFalse(h.fake.window(b.identity)!.isMinimized)
        XCTAssertEqual(h.fake.frame(of: b.identity), LayoutEngine.frames(for: .focus, count: 2, in: h.area)[1])
    }
}
