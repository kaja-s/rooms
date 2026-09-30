import Foundation
import XCTest
@testable import RoomsCore
@testable import RoomsKit

/// Builds an `AppController` on a `FakeWindowSystem` with a `RoomStore` in a fresh temporary directory.
final class TestHarness {
    let fake = FakeWindowSystem()
    let directory: URL
    let store: RoomStore
    let defaults: UserDefaults
    let controller: AppController

    init(firstLaunch: Bool = false) {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("rooms-kit-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = RoomStore(fileURL: directory.appendingPathComponent("rooms.json"))
        defaults = UserDefaults(suiteName: "dev.rooms.tests.\(UUID().uuidString)")!
        if !firstLaunch { defaults.set(true, forKey: AppController.hasLaunchedBeforeKey) }
        controller = AppController(store: store, windowSystem: fake, defaults: defaults)
        controller.start()
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func reload() -> [Room] { RoomStore(fileURL: store.fileURL).load() }

    @discardableResult
    func app(_ bundle: String, pid: Int32, name: String) -> RunningApplication {
        fake.addApplication(bundleIdentifier: bundle, processIdentifier: pid, name: name)
    }

    @discardableResult
    func window(_ app: RunningApplication, id: UInt32, title: String, frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
                minimumSize: CGSize = CGSize(width: 300, height: 200), minimized: Bool = false) -> AppWindow {
        let identity = fake.addWindow(of: app, windowID: id, title: title, frame: frame, minimumSize: minimumSize, isMinimized: minimized)
        return AppWindow(identity: identity, applicationName: app.name, title: title, frame: frame, minimumSize: minimumSize)
    }

    /// Writes rooms to the store and reloads the controller from it.
    func seed(_ rooms: [Room]) {
        try! store.save(rooms)
        controller.start()
    }
}
