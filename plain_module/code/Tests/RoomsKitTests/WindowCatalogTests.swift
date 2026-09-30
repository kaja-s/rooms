import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class WindowCatalogTests: XCTestCase {
    func testListReturnsNilWithoutPermission() {
        let fake = FakeWindowSystem()
        fake.accessibilityPermission = false
        XCTAssertNil(WindowCatalog(system: fake).listWindows())
        fake.accessibilityPermission = true
        XCTAssertEqual(WindowCatalog(system: fake).listWindows(), [])
    }

    func testMeasureMinimumSizeRestoresFrame() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let original = CGRect(x: 50, y: 60, width: 700, height: 500)
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: original, minimumSize: CGSize(width: 320, height: 240))
        let catalog = WindowCatalog(system: fake)
        let measured = catalog.measureMinimumSize(of: fake.listWindows()[0])
        XCTAssertEqual(measured, CGSize(width: 320, height: 240))
        XCTAssertEqual(fake.frame(of: id), original)
        XCTAssertEqual(fake.operations, [.setSize(id, CGSize(width: 1, height: 1)), .setFrame(id, original)])
    }

    func testMeasureWaitsForDelayedResize() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let original = CGRect(x: 0, y: 0, width: 800, height: 600)
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: original, minimumSize: CGSize(width: 400, height: 300))
        fake.setResizeBehavior(of: id, delayMilliseconds: 120)
        let measured = WindowCatalog(system: fake).measureMinimumSize(of: fake.listWindows()[0])
        XCTAssertEqual(measured, CGSize(width: 400, height: 300))
        XCTAssertEqual(fake.waitedMilliseconds, 200)
    }

    func testMeasureRecordsUnshrunkDimensionAsZero() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        fake.setResizeBehavior(of: id, ignoresResize: true)
        let measured = WindowCatalog(system: fake).measureMinimumSize(of: fake.listWindows()[0])
        XCTAssertEqual(measured, .zero)
        XCTAssertEqual(fake.waitedMilliseconds, 500)
        XCTAssertEqual(fake.frame(of: id), CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    func testFindKeepsSavedMinimumSize() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: .zero)
        var saved = fake.listWindows()[0]
        saved.minimumSize = CGSize(width: 111, height: 222)
        let found = WindowCatalog(system: fake).find([saved])
        XCTAssertEqual(found[0]?.identity, id)
        XCTAssertEqual(found[0]?.minimumSize, CGSize(width: 111, height: 222))
    }

    func testMoveRetriesOnceAfter100ms() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: CGRect(x: 0, y: 0, width: 800, height: 600), minimumSize: CGSize(width: 500, height: 500))
        let settled = WindowCatalog(system: fake).move(id, to: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(settled.size, CGSize(width: 500, height: 500))
        XCTAssertEqual(fake.waitedMilliseconds, 100)
        XCTAssertEqual(fake.operations.count, 2)
        fake.clearOperations()
        WindowCatalog(system: fake).move(id, to: CGRect(x: 0, y: 0, width: 600, height: 600))
        XCTAssertEqual(fake.operations.count, 1)
        XCTAssertEqual(fake.waitedMilliseconds, 100)
    }
}
