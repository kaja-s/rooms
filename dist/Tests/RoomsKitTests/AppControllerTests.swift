import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class AppControllerTests: XCTestCase {
    func testStartLoadsRoomsAndFirstLaunchOpensGettingStarted() {
        let h = TestHarness(firstLaunch: true)
        XCTAssertTrue(h.controller.gettingStarted.isPresented)
        XCTAssertTrue(h.defaults.bool(forKey: AppController.hasLaunchedBeforeKey))
        h.controller.gettingStarted.done()
        h.controller.start()
        XCTAssertFalse(h.controller.gettingStarted.isPresented)
    }

    func testCreateRoomMeasuresPersistsAndShows() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 320, height: 240))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 100, height: 100))
        h.controller.createRoom(named: "Design", windows: [b, a].map { var w = $0; w.minimumSize = .zero; return w })
        let room = h.controller.rooms[0]
        XCTAssertEqual(room.name, "Design")
        XCTAssertEqual(room.windows.map { $0.identity.windowID }, [2, 1])
        XCTAssertEqual(room.windows[1].minimumSize, CGSize(width: 320, height: 240))
        XCTAssertEqual(room.layout, .auto)
        XCTAssertNil(room.directKey)
        XCTAssertEqual(h.controller.currentRoomID, room.id)
        XCTAssertNotNil(h.reload()[0].lastShown)
    }

    func testShowRoomLaysOutHidesAndFocuses() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B", minimized: true)
        let c = h.window(x, id: 3, title: "C")
        h.window(y, id: 4, title: "D")
        h.seed([Room(name: "R", windows: [a, b], layout: .columns)])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertTrue(h.fake.isHidden(application: 2))
        XCTAssertTrue(h.fake.window(c.identity)!.isMinimized)
        XCTAssertFalse(h.fake.window(b.identity)!.isMinimized)
        let frames = LayoutEngine.frames(for: .columns, count: 2, in: h.fake.visibleArea)
        XCTAssertEqual(h.fake.frame(of: a.identity), frames[0])
        XCTAssertEqual(h.fake.frame(of: b.identity), frames[1])
        XCTAssertEqual(h.fake.raiseOrder.last, a.identity)
        XCTAssertEqual(h.fake.focusedByOperation, a.identity)
        XCTAssertEqual(h.controller.currentRoom?.name, "R")
        XCTAssertEqual(h.fake.windows.count, 4)
    }

    func testShowRoomWithQuitApplicationAsksToOpenIt() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Gone", windows: [a])])
        h.fake.quitApplication(processIdentifier: 1)
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.controller.notificationMessage, "Open X, then open “Gone” again")
        XCTAssertTrue(h.fake.operations.isEmpty)
        XCTAssertNil(h.controller.currentRoomID)
    }

    func testJoinedNames() {
        XCTAssertEqual(AppController.joinedNames(["A"]), "A")
        XCTAssertEqual(AppController.joinedNames(["A", "B"]), "A and B")
        XCTAssertEqual(AppController.joinedNames(["A", "B", "C"]), "A, B and C")
    }

    func testShowRoomWithClosedWindowAsksToOpenItsApp() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = AppWindow(identity: WindowIdentity(bundleIdentifier: x.bundleIdentifier, processIdentifier: 1, windowID: 77), applicationName: "X", title: "Closed", frame: .zero)
        h.seed([Room(name: "Gone", windows: [a])])
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertEqual(h.controller.notificationMessage, "Open X, then open “Gone” again")
        XCTAssertTrue(h.fake.operations.isEmpty)
        XCTAssertNil(h.controller.currentRoomID)
    }

    func testShowRoomWithoutPermissionShowsDialog() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "R", windows: [a])])
        h.fake.accessibilityPermission = false
        h.controller.showRoom(id: h.controller.rooms[0].id)
        XCTAssertNotNil(h.controller.permissionDialog)
        h.controller.permissionDialogOpenSettings()
        XCTAssertEqual(h.fake.operations, [.openAccessibilitySettings])
        XCTAssertNil(h.controller.permissionDialog)
    }

    func testDirectKeys() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.seed([Room(name: "A", windows: [a]), Room(name: "B", windows: [b])])
        let idA = h.controller.rooms[0].id, idB = h.controller.rooms[1].id
        h.controller.assignDirectKey(3, toRoom: idA)
        h.controller.assignDirectKey(3, toRoom: idB)
        XCTAssertNil(h.controller.room(idA)?.directKey)
        XCTAssertEqual(h.controller.room(idB)?.directKey, 3)
        h.controller.directKeyPressed(3)
        XCTAssertEqual(h.controller.currentRoomID, idB)
        h.controller.directKeyPressed(7)
        XCTAssertEqual(h.controller.currentRoomID, idB)
        h.controller.assignDirectKey(3, toRoom: idB)
        XCTAssertNil(h.reload()[1].directKey)
    }

    func testSnapKeysCycleThirds() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.fake.focusedWindowIdentity = a.identity
        let area = h.fake.visibleArea
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.leftHalf, in: area))
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.leftThird, in: area))
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.leftTwoThirds, in: area))
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.leftHalf, in: area))
        h.controller.snapKeyPressed(.right)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.rightHalf, in: area))
        h.controller.snapKeyPressed(.up)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.topHalf, in: area))
        h.controller.snapKeyPressed(.down)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.bottomHalf, in: area))
        h.controller.snapKeyPressed(.fill)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.fill, in: area))
        // Moving the window by hand resets the cycle.
        h.controller.snapKeyPressed(.left)
        h.fake.setFrame(CGRect(x: 300, y: 300, width: 400, height: 400), of: a.identity)
        h.controller.snapKeyPressed(.left)
        XCTAssertEqual(h.fake.frame(of: a.identity), LayoutEngine.snapFrame(.leftHalf, in: area))
    }

    func testSnapKeyWithoutFocusedWindowDoesNothing() {
        let h = TestHarness()
        h.controller.snapKeyPressed(.left)
        XCTAssertTrue(h.fake.operations.isEmpty)
    }

    func testSaveVisibleWindowsRecognizesColumnsWithoutMovingAndNamesRoom() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let columns = LayoutEngine.frames(for: .columns, count: 2, in: h.fake.visibleArea)
        let a = h.window(x, id: 1, title: "A", frame: columns[0].offsetBy(dx: 10, dy: 0))
        let b = h.window(x, id: 2, title: "B", frame: columns[1].offsetBy(dx: -15, dy: 5))
        h.seed([Room(name: "Room 1", windows: [a]), Room(name: "room 3", windows: [a])])
        h.fake.clearOperations()
        let room = h.controller.saveVisibleWindowsAsNewRoom()!
        XCTAssertEqual(room.name, "Room 2")
        XCTAssertEqual(room.layout, .columns)
        XCTAssertEqual(room.windows.map { $0.identity }, [a.identity, b.identity])
        XCTAssertEqual(h.controller.currentRoomID, room.id)
        XCTAssertEqual(h.fake.frame(of: a.identity), columns[0].offsetBy(dx: 10, dy: 0), "no window moves")
        XCTAssertFalse(h.fake.operations.contains { if case .setFrame(_, let f) = $0 { return f != columns[0].offsetBy(dx: 10, dy: 0) && f != columns[1].offsetBy(dx: -15, dy: 5) } else { return false } })
        XCTAssertEqual(h.reload().last?.name, "Room 2")
    }

    func testSaveVisibleWindowsSkipsMinimizedHiddenAndOffScreen() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        h.window(x, id: 2, title: "Min", minimized: true)
        h.window(y, id: 3, title: "Hidden")
        h.window(x, id: 4, title: "Off", frame: CGRect(x: 5000, y: 100, width: 400, height: 300))
        h.fake.setHidden(true, application: 2)
        let room = h.controller.saveVisibleWindowsAsNewRoom()!
        XCTAssertEqual(room.windows.map { $0.identity }, [a.identity])
        XCTAssertEqual(room.layout, .auto)
    }

    func testSaveVisibleWindowsWithNothingVisibleSavesNothing() {
        let h = TestHarness()
        XCTAssertNil(h.controller.saveVisibleWindowsAsNewRoom())
        XCTAssertTrue(h.controller.rooms.isEmpty)
    }

    func testSetLayoutRelayoutsCurrentRoom() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.seed([Room(name: "R", windows: [a, b], layout: .focus)])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        h.controller.setLayout(.columns, ofRoom: id)
        XCTAssertEqual(h.fake.frame(of: b.identity), LayoutEngine.frames(for: .columns, count: 2, in: h.fake.visibleArea)[1])
        XCTAssertEqual(h.reload()[0].layout, .columns)
    }

    func testReplaceWindowsReplacesAndMeasures() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        let c = h.window(x, id: 3, title: "C")
        h.seed([Room(name: "R", windows: [a, b], layout: .focus)])
        let id = h.controller.rooms[0].id
        h.controller.replaceWindows(ofRoom: id, with: [a, c])
        XCTAssertEqual(h.controller.room(id)?.windows.map { $0.identity.windowID }, [1, 3])
        XCTAssertEqual(h.controller.room(id)?.windows[0].minimumSize, CGSize(width: 300, height: 200))
    }

    func testReplaceWindowsOfCurrentRoomShowsItAgain() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(x, id: 2, title: "B")
        h.seed([Room(name: "R", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        h.fake.clearOperations()
        h.controller.replaceWindows(ofRoom: id, with: [a, b])
        XCTAssertTrue(h.fake.raiseOrder.contains(b.identity))
    }

    func testRenameAndDelete() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a]), Room(name: "Deep Work", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.rename(room: id, to: "deep work")
        XCTAssertEqual(h.controller.room(id)?.name, "Design")
        h.controller.rename(room: id, to: "  Design 2 ")
        XCTAssertEqual(h.reload()[0].name, "Design 2")
        h.controller.showRoom(id: id)
        h.fake.clearOperations()
        h.controller.deleteRoom(id: id)
        XCTAssertNil(h.controller.currentRoomID)
        XCTAssertEqual(h.reload().count, 1)
        XCTAssertTrue(h.fake.operations.isEmpty)
    }

    func testBeginRenameAndEditWindowsAndQuit() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.beginRename(ofRoom: id)
        XCTAssertEqual(h.controller.renameDialog?.title, "Rename “Design”")
        h.controller.renameDialog?.cancel()
        XCTAssertNil(h.controller.renameDialog)
        h.controller.beginEditWindows(ofRoom: id)
        XCTAssertTrue(h.controller.picker.isPresented)
        XCTAssertEqual(h.controller.picker.mode, .edit(roomID: id))
        var quit = false
        h.controller.onQuit = { quit = true }
        h.controller.quit()
        XCTAssertTrue(quit)
        XCTAssertTrue(h.controller.quitRequested)
    }
}
