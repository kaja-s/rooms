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

final class CommandSNewRoomTests: XCTestCase {
    func testAcceptanceSavesVisibleColumnsWindowsAsRoom2() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let columns = LayoutEngine.frames(for: .columns, count: 3, in: h.area)
        let offsets: [CGSize] = [CGSize(width: 0, height: 0), CGSize(width: 20, height: 0), CGSize(width: 0, height: -18)]
        var windows: [AppWindow] = []
        for i in 0..<3 {
            let frame = columns[i].offsetBy(dx: offsets[i].width, dy: offsets[i].height)
            windows.append(h.window(x, id: UInt32(i + 1), title: "W\(i)", frame: frame))
        }
        h.seed([Room(name: "Room 1", windows: [windows[0]], createdAt: Date(timeIntervalSince1970: 1)),
                Room(name: "room 3", windows: [windows[0]], createdAt: Date(timeIntervalSince1970: 2))])
        let palette = h.controller.palette
        palette.open()
        palette.pressCommandS()
        let room = h.controller.rooms.first { $0.name == "Room 2" }
        XCTAssertNotNil(room)
        XCTAssertEqual(room?.layout, .columns)
        XCTAssertEqual(room?.windows.map { $0.identity }, windows.map { $0.identity }, "front to back")
        XCTAssertEqual(h.controller.currentRoomID, room?.id)
        XCTAssertEqual(palette.rows[palette.selectedIndex].roomID, room?.id)
        XCTAssertTrue(palette.isVisible, "the palette stays open")
        XCTAssertTrue(palette.leadingFooterHints.contains("Saved “Room 2”"))
        XCTAssertTrue(h.reload().contains { $0.name == "Room 2" && $0.layout == .columns })
    }

    func testAcceptanceUntidyWindowsSaveOnAutoWithoutMoving() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", frame: CGRect(x: 13, y: 21, width: 300, height: 200))
        let b = h.window(x, id: 2, title: "B", frame: CGRect(x: 700, y: 500, width: 300, height: 200))
        h.controller.palette.open()
        h.controller.palette.pressCommandS()
        let room = h.controller.rooms.last
        XCTAssertEqual(room?.name, "Room 1")
        XCTAssertEqual(room?.layout, .auto)
        XCTAssertEqual(h.fake.frame(of: a.identity), CGRect(x: 13, y: 21, width: 300, height: 200))
        XCTAssertEqual(h.fake.frame(of: b.identity), CGRect(x: 700, y: 500, width: 300, height: 200))
    }

    func testAcceptanceMinimizedAndHiddenWindowsAreLeftOut() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        h.window(x, id: 2, title: "Minimized", minimized: true)
        h.window(y, id: 3, title: "Hidden app")
        h.fake.setHidden(true, application: 2)
        h.controller.palette.open()
        h.controller.palette.pressCommandS()
        XCTAssertEqual(h.controller.rooms.last?.windows.map { $0.identity }, [a.identity])
    }

    func testRecognizesStackAndMeasuresMinimumSizes() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let stack = LayoutEngine.frames(for: .stack, count: 2, in: h.area)
        h.window(x, id: 1, title: "A", frame: stack[0], minimumSize: CGSize(width: 320, height: 240))
        h.window(x, id: 2, title: "B", frame: stack[1], minimumSize: CGSize(width: 330, height: 250))
        h.controller.palette.open()
        h.controller.palette.pressCommandS()
        let room = h.controller.rooms.last!
        XCTAssertEqual(room.layout, .stack)
        XCTAssertEqual(room.windows.map { $0.minimumSize }, [CGSize(width: 320, height: 240), CGSize(width: 330, height: 250)])
    }

    func testWorksFromCreateRowAndEmptyList() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A")
        let palette = h.controller.palette
        palette.open()
        palette.query = "something new"
        XCTAssertTrue(palette.isCreateRowSelected)
        palette.pressCommandS()
        XCTAssertEqual(h.controller.rooms.map { $0.name }, ["Room 1"])
        XCTAssertEqual(palette.rows[palette.selectedIndex].roomID, h.controller.rooms[0].id)
    }

    func testNothingVisibleSavesNothing() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "Minimized", minimized: true)
        h.window(x, id: 2, title: "Elsewhere", frame: CGRect(x: 5000, y: 100, width: 400, height: 300))
        let palette = h.controller.palette
        palette.open()
        palette.pressCommandS()
        XCTAssertTrue(h.controller.rooms.isEmpty)
        XCTAssertNil(palette.savedHint)
        XCTAssertTrue(palette.leadingFooterHints.contains("⌘S New room"))
    }

    func testSavedHintReturnsAfterItsDuration() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A")
        let palette = h.controller.palette
        XCTAssertEqual(palette.savedHintDuration, 2)
        palette.savedHintDuration = 0.1
        palette.open()
        palette.pressCommandS()
        XCTAssertEqual(palette.savedHint, "Saved “Room 1”")
        let cleared = expectation(description: "hint cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { cleared.fulfill() }
        wait(for: [cleared], timeout: 2)
        XCTAssertNil(palette.savedHint)
        XCTAssertTrue(palette.leadingFooterHints.contains("⌘S New room"))
    }
}
