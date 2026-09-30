import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class WindowPickerViewModelTests: XCTestCase {
    func testCreateModePresentsCards() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "Xcode")
        h.window(x, id: 1, title: "")
        h.window(x, id: 2, title: "Second")
        h.fake.visibleArea = CGRect(x: 0, y: 0, width: 1000, height: 600)
        h.controller.beginCreateRoom(named: "Alpha")
        let picker = h.controller.picker
        XCTAssertTrue(picker.isPresented)
        XCTAssertEqual(picker.title, "Choose the windows for “Alpha”")
        XCTAssertEqual(picker.screenArea, h.fake.visibleArea)
        XCTAssertEqual(picker.cards.map { $0.title }, ["Xcode", "Second"])
        XCTAssertNotNil(picker.cards[0].snapshot)
        XCTAssertNotNil(picker.cards[0].icon)
        XCTAssertFalse(picker.showsAppIconInsteadOfSnapshot)
        XCTAssertEqual(picker.primaryButtonTitle, "Create Room")
        XCTAssertEqual(picker.cancelButtonTitle, "Cancel")
        XCTAssertFalse(picker.isPrimaryEnabled)
        picker.cancel()
        XCTAssertFalse(picker.isPresented)
        XCTAssertTrue(h.controller.rooms.isEmpty)
    }

    func testWithoutScreenRecordingCardsShowIcon() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "Xcode")
        h.window(x, id: 1, title: "A")
        h.fake.screenRecordingPermission = false
        h.controller.beginCreateRoom(named: "Alpha")
        XCTAssertTrue(h.controller.picker.showsAppIconInsteadOfSnapshot)
        XCTAssertNil(h.controller.picker.cards[0].snapshot)
    }

    func testWithoutAccessibilityPickerDoesNotOpen() {
        let h = TestHarness()
        h.fake.accessibilityPermission = false
        h.controller.beginCreateRoom(named: "Alpha")
        XCTAssertFalse(h.controller.picker.isPresented)
        XCTAssertEqual(h.controller.permissionDialog?.message, "Rooms needs Accessibility access to see and move windows")
        h.controller.permissionDialogCancel()
        XCTAssertNil(h.controller.permissionDialog)
    }

    func testToggleNumbersAndRenumbers() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A"); h.window(x, id: 2, title: "B"); h.window(x, id: 3, title: "C")
        h.controller.beginCreateRoom(named: "R")
        let picker = h.controller.picker
        picker.toggleCard(at: 1); picker.toggleCard(at: 0); picker.toggleCard(at: 2)
        XCTAssertEqual(picker.cards.map { $0.badge }, [2, 1, 3])
        XCTAssertTrue(picker.isPrimaryEnabled)
        picker.toggleCard(at: 1)
        XCTAssertEqual(picker.cards.map { $0.badge }, [1, nil, 2])
        XCTAssertFalse(picker.cards[1].isSelected)
        picker.toggleCard(at: 1)
        XCTAssertEqual(picker.cards.map { $0.badge }, [1, 3, 2])
        XCTAssertEqual(picker.selectedWindows.map { $0.title }, ["A", "C", "B"])
    }

    func testConfirmCreatesRoomInBadgeOrder() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        h.window(x, id: 1, title: "A"); h.window(x, id: 2, title: "B"); h.window(x, id: 3, title: "C")
        h.controller.beginCreateRoom(named: "R")
        let picker = h.controller.picker
        picker.confirm()
        XCTAssertTrue(picker.isPresented, "confirm is ignored while nothing is selected")
        picker.toggleCard(at: 1); picker.toggleCard(at: 0); picker.toggleCard(at: 2)
        picker.confirm()
        XCTAssertFalse(picker.isPresented)
        XCTAssertEqual(h.controller.rooms[0].windows.map { $0.title }, ["B", "A", "C"])
        XCTAssertEqual(h.controller.currentRoom?.name, "R")
    }

    func testEditModePreselectsFoundWindows() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        let gone = AppWindow(identity: WindowIdentity(bundleIdentifier: "z", processIdentifier: 9, windowID: 9), applicationName: "Z", title: "Z", frame: .zero)
        h.seed([Room(name: "Design", windows: [b, gone, a])])
        let id = h.controller.rooms[0].id
        h.controller.beginEditWindows(ofRoom: id)
        let picker = h.controller.picker
        XCTAssertEqual(picker.title, "Edit the windows of “Design”")
        XCTAssertEqual(picker.primaryButtonTitle, "Save Room")
        XCTAssertEqual(picker.roomName, "Design")
        XCTAssertEqual(picker.cards.map { $0.badge }, [2, 1])
        picker.toggleCard(at: 1)
        picker.toggleCard(at: 1)
        XCTAssertEqual(picker.cards.map { $0.badge }, [1, 2])
        picker.confirm()
        XCTAssertEqual(h.controller.room(id)?.windows.map { $0.title }, ["A", "B"])
    }
}
