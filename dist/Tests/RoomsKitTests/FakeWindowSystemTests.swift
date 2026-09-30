import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class FakeWindowSystemTests: XCTestCase {
    func testListingExcludesNonStandardAndOwnWindows() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        fake.addWindow(of: app, windowID: 1, title: "Std", frame: .zero)
        fake.addWindow(of: app, windowID: 2, title: "Panel", frame: .zero, isStandard: false)
        fake.addWindow(of: app, windowID: 3, title: "Own", frame: .zero, isRoomsOwn: true)
        XCTAssertEqual(fake.listWindows().map { $0.identity.windowID }, [1])
    }

    func testSetFrameHonoursMinimumSizeAndRecords() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: CGRect(x: 0, y: 0, width: 500, height: 500), minimumSize: CGSize(width: 300, height: 200))
        fake.setFrame(CGRect(x: 10, y: 10, width: 100, height: 100), of: id)
        XCTAssertEqual(fake.frame(of: id), CGRect(x: 10, y: 10, width: 300, height: 200))
        XCTAssertEqual(fake.operations, [.setFrame(id, CGRect(x: 10, y: 10, width: 100, height: 100))])
    }

    func testMinimizeHideFocusAndQuit() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: .zero)
        fake.setMinimized(true, id)
        XCTAssertTrue(fake.isMinimized(id))
        fake.setHidden(true, application: 1)
        XCTAssertTrue(fake.isHidden(application: 1))
        fake.focus(id)
        XCTAssertEqual(fake.focusedWindow(), id)
        XCTAssertEqual(fake.focusedByOperation, id)
        fake.quitApplication(processIdentifier: 1)
        XCTAssertTrue(fake.listWindows().isEmpty)
        XCTAssertTrue(fake.runningApplications().isEmpty)
        XCTAssertFalse(fake.isHidden(application: 1))
    }

    func testPermissionsAndImages() {
        let fake = FakeWindowSystem()
        let app = fake.addApplication(bundleIdentifier: "a", processIdentifier: 1, name: "A")
        let id = fake.addWindow(of: app, windowID: 1, title: "W", frame: .zero)
        XCTAssertNotNil(fake.snapshot(of: id))
        fake.screenRecordingPermission = false
        XCTAssertNil(fake.snapshot(of: id))
        XCTAssertNotNil(fake.icon(forBundleIdentifier: "a"))
        fake.openAccessibilitySettings()
        XCTAssertEqual(fake.operations, [.openAccessibilitySettings])
        fake.wait(milliseconds: 100)
        XCTAssertEqual(fake.waitedMilliseconds, 100)
    }
}
