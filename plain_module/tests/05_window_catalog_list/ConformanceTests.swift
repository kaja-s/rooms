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

final class WindowCatalogListTests: XCTestCase {
    func testListsStandardWindowsOfAllAppsIncludingMinimizedAndHidden() {
        let h = Harness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        h.window(x, id: 1, title: "A")
        h.window(x, id: 2, title: "Minimized", minimized: true)
        h.window(y, id: 3, title: "Hidden app window")
        h.fake.setHidden(true, application: 2)
        h.window(x, id: 4, title: "Tooltip", standard: false)
        h.window(x, id: 5, title: "Rooms palette", own: true)
        let listed = h.controller.catalog.listWindows()
        XCTAssertEqual(listed?.map { $0.identity.windowID }, [1, 2, 3])
        XCTAssertEqual(listed?[0].applicationName, "X")
    }

    func testMissingAccessibilityPermissionShowsDialog() {
        let h = Harness()
        h.fake.accessibilityPermission = false
        XCTAssertNil(h.controller.catalog.listWindows())
        h.controller.beginCreateRoom(named: "Any")
        let dialog = h.controller.permissionDialog
        XCTAssertEqual(dialog?.message, "Rooms needs Accessibility access to see and move windows")
        XCTAssertEqual(dialog?.openSettingsButtonTitle, "Open System Settings")
        XCTAssertEqual(dialog?.cancelButtonTitle, "Cancel")
        h.controller.permissionDialogOpenSettings()
        XCTAssertEqual(h.fake.operations, [.openAccessibilitySettings])
        XCTAssertNil(h.controller.permissionDialog)
        h.fake.accessibilityPermission = false
        h.controller.beginCreateRoom(named: "Any")
        h.controller.permissionDialogCancel()
        XCTAssertNil(h.controller.permissionDialog)
        XCTAssertEqual(h.fake.operations.count, 1)
    }
}
