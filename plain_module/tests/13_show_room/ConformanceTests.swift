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

final class ShowRoomTests: XCTestCase {
    func testReturnOnRowShowsRoomAndClosesPalette() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B", minimized: true)
        let c = h.window(x, id: 3, title: "C")
        h.seed([Room(name: "R", windows: [a, b, c], layout: .focus)])
        let palette = h.controller.palette
        palette.open()
        palette.pressReturn()
        XCTAssertFalse(palette.isVisible)
        let frames = LayoutEngine.frames(for: .focus, count: 3, in: h.area)
        XCTAssertEqual(h.fake.frame(of: a.identity), frames[0])
        XCTAssertEqual(h.fake.frame(of: b.identity), frames[1])
        XCTAssertEqual(h.fake.frame(of: c.identity), frames[2])
        XCTAssertFalse(h.fake.window(b.identity)!.isMinimized)
        XCTAssertEqual(h.fake.raiseOrder.last, a.identity)
        XCTAssertEqual(h.fake.focusedByOperation, a.identity)
    }

    func testAcceptanceFocusRoomThreeWindows() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B", minimized: true)
        let c = h.window(x, id: 3, title: "C")
        h.seed([Room(name: "R", windows: [a, b, c], layout: .focus)])
        h.controller.palette.open()
        h.controller.palette.clickRow(0)
        XCTAssertEqual(h.fake.frame(of: a.identity), CGRect(x: 8, y: 8, width: 944, height: 884))
        XCTAssertEqual(h.fake.frame(of: b.identity), CGRect(x: 960, y: 454, width: 472, height: 438))
        XCTAssertEqual(h.fake.frame(of: c.identity), CGRect(x: 960, y: 8, width: 472, height: 438))
        XCTAssertTrue(h.fake.operations.contains(.unminimize(b.identity)))
        XCTAssertEqual(h.fake.raiseOrder.last, a.identity)
        XCTAssertEqual(h.fake.focusedWindowIdentity, a.identity)
    }

    func testClosedMainWindowStopsTheRoom() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        h.app("y", pid: 2, name: "Y")
        // The main window was closed, but its application still runs.
        let main = AppWindow(identity: WindowIdentity(bundleIdentifier: "y", processIdentifier: 2, windowID: 9), applicationName: "Y", title: "Main", frame: .zero)
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "R", windows: [main, a], layout: .columns)])
        h.fake.clearOperations()
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.controller.notificationMessage, "Open Y, then open “R” again")
        XCTAssertTrue(h.fake.operations.isEmpty)
        XCTAssertEqual(h.fake.frame(of: a.identity), CGRect(x: 100, y: 100, width: 800, height: 600))
    }

    func testAutoIsResolved() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 1000, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 1000, height: 100))
        h.seed([Room(name: "Auto", windows: [a, b], layout: .auto)])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.frames(for: .stack, count: 2, in: h.area)[0])
    }

    private func seedDesign(_ h: Harness) -> (UUID, [AppWindow]) {
        let figma = h.app("com.figma.Desktop", pid: 1, name: "Figma")
        let linear = h.app("com.linear", pid: 2, name: "Linear")
        let dia = h.app("company.thebrowser.dia", pid: 3, name: "Dia")
        let windows = [h.window(figma, id: 1, title: "File"), h.window(linear, id: 2, title: "Issues"), h.window(dia, id: 3, title: "Docs")]
        h.seed([Room(name: "Design", windows: windows, layout: .columns)])
        return (h.controller.rooms[0].id, windows)
    }

    func testAcceptanceQuitApplicationAsksToOpenIt() {
        let h = Harness()
        let (id, windows) = seedDesign(h)
        h.fake.quitApplication(processIdentifier: 1)
        h.fake.clearOperations()
        h.controller.showRoom(id: id)
        XCTAssertEqual(h.controller.notificationMessage, "Open Figma, then open “Design” again")
        XCTAssertTrue(h.fake.operations.isEmpty, "nothing moved, hidden, or raised")
        XCTAssertEqual(h.fake.frame(of: windows[1].identity), CGRect(x: 100, y: 100, width: 800, height: 600))
        XCTAssertNil(h.controller.currentRoomID)
    }

    func testAcceptanceTwoQuitApplicationsAreJoined() {
        let h = Harness()
        let (id, _) = seedDesign(h)
        h.fake.quitApplication(processIdentifier: 1)
        h.fake.quitApplication(processIdentifier: 2)
        h.controller.showRoom(id: id)
        XCTAssertEqual(h.controller.notificationMessage, "Open Figma and Linear, then open “Design” again")
    }

    func testDirectKeyUsesTheSameCheck() {
        let h = Harness()
        let (id, _) = seedDesign(h)
        h.controller.assignDirectKey(4, toRoom: id)
        h.fake.quitApplication(processIdentifier: 3)
        h.controller.directKeyPressed(4)
        XCTAssertEqual(h.controller.notificationMessage, "Open Dia, then open “Design” again")
    }

    func testAcceptanceClosedWindowWhileAppRunsAsksToOpenIt() {
        let h = Harness()
        let figma = h.app("com.figma.Desktop", pid: 1, name: "Figma")
        let linear = h.app("com.linear", pid: 2, name: "Linear")
        let dia = h.app("company.thebrowser.dia", pid: 3, name: "Dia")
        // The Figma window was closed; Figma keeps running with no window.
        let closed = AppWindow(identity: WindowIdentity(bundleIdentifier: figma.bundleIdentifier, processIdentifier: 1, windowID: 1), applicationName: "Figma", title: "File", frame: .zero)
        let windows = [closed, h.window(linear, id: 2, title: "Issues"), h.window(dia, id: 3, title: "Docs")]
        h.seed([Room(name: "Design", windows: windows, layout: .columns)])
        XCTAssertTrue(h.fake.runningApplications().contains { $0.name == "Figma" })
        h.fake.clearOperations()
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.controller.notificationMessage, "Open Figma, then open “Design” again")
        XCTAssertTrue(h.fake.operations.isEmpty, "nothing moved or hidden")
    }
}
