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

final class CardSelectionTests: XCTestCase {
    private func picker(_ h: Harness) -> WindowPickerViewModel {
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A"); h.window(x, id: 2, title: "B"); h.window(x, id: 3, title: "C")
        h.controller.beginCreateRoom(named: "R")
        return h.controller.picker
    }

    func testClickingNumbersInSelectionOrder() {
        let h = Harness()
        let picker = picker(h)
        XCTAssertEqual(picker.cards.map { $0.badge }, [nil, nil, nil])
        XCTAssertFalse(picker.isPrimaryEnabled)
        picker.toggleCard(at: 2)
        XCTAssertEqual(picker.cards.map { $0.badge }, [nil, nil, 1])
        XCTAssertTrue(picker.cards[2].isSelected)
        XCTAssertTrue(picker.isPrimaryEnabled)
        picker.toggleCard(at: 0)
        XCTAssertEqual(picker.cards.map { $0.badge }, [2, nil, 1])
    }

    func testDeselectingRenumbersToCloseTheGap() {
        let h = Harness()
        let picker = picker(h)
        picker.toggleCard(at: 0); picker.toggleCard(at: 1); picker.toggleCard(at: 2)
        picker.toggleCard(at: 0)
        XCTAssertEqual(picker.cards.map { $0.badge }, [nil, 1, 2])
        XCTAssertFalse(picker.cards[0].isSelected)
        picker.toggleCard(at: 1); picker.toggleCard(at: 2)
        XCTAssertFalse(picker.isPrimaryEnabled, "Create Room disabled with nothing selected")
    }
}
