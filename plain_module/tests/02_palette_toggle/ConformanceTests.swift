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

final class PaletteToggleTests: XCTestCase {
    func testOptionSpaceTogglesPaletteOnCurrentScreen() {
        let h = Harness()
        h.fake.visibleArea = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        let palette = h.controller.palette
        XCTAssertFalse(palette.isVisible)
        h.controller.toggleHotkeyPressed()
        XCTAssertTrue(palette.isVisible)
        XCTAssertEqual(palette.query, "", "text field is empty")
        XCTAssertEqual(palette.screenArea, h.fake.visibleArea, "opens on the screen the pointer is on")
        h.controller.toggleHotkeyPressed()
        XCTAssertFalse(palette.isVisible)
    }

    func testShowPaletteMenuItemOpensIt() {
        let h = Harness()
        h.controller.statusMenu.perform(.showPalette)
        XCTAssertTrue(h.controller.palette.isVisible)
    }

    func testEscapeAndClickOutsideClose() {
        let h = Harness()
        let palette = h.controller.palette
        palette.open()
        palette.pressEscape()
        XCTAssertFalse(palette.isVisible)
        palette.open()
        palette.clickedOutside()
        XCTAssertFalse(palette.isVisible)
    }

    func testTypedTextIsClearedOnReopen() {
        let h = Harness()
        let palette = h.controller.palette
        palette.open()
        palette.query = "abc"
        palette.close()
        palette.open()
        XCTAssertEqual(palette.query, "")
    }

    func testFooterKeyHints() {
        let h = Harness()
        let hints = h.controller.palette.footerHints
        XCTAssertTrue(hints.contains("↵ Go"))
        XCTAssertTrue(hints.contains("esc Close"))
        XCTAssertEqual(hints.suffix(2), ["↵ Go", "esc Close"])
    }
}
