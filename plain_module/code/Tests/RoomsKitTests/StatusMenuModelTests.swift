import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class StatusMenuModelTests: XCTestCase {
    func testItemsWithoutCurrentRoom() {
        let h = TestHarness()
        let items = h.controller.statusMenu.items
        XCTAssertEqual(items.map { $0.title }, ["No room", "Show Palette", "Edit Windows…", "Rename…", "Getting Started", "Quit Rooms"])
        XCTAssertEqual(items.map { $0.isEnabled }, [false, true, false, false, true, true])
        XCTAssertEqual(items[1].keyEquivalentHint, "⌥Space")
        XCTAssertEqual(h.controller.statusMenu.headerTitle, "No room")
    }

    func testItemsWithCurrentRoomAndActions() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.showRoom(id: id)
        let menu = h.controller.statusMenu
        XCTAssertEqual(menu.items[0].title, "Design")
        XCTAssertTrue(menu.items[2].isEnabled)
        XCTAssertTrue(menu.items[3].isEnabled)
        menu.perform(.rename)
        XCTAssertEqual(h.controller.renameDialog?.roomID, id)
        h.controller.renameDialog?.cancel()
        menu.perform(.editWindows)
        XCTAssertEqual(h.controller.picker.mode, .edit(roomID: id))
        h.controller.picker.cancel()
        menu.perform(.gettingStarted)
        XCTAssertTrue(h.controller.gettingStarted.isPresented)
        menu.perform(.header)
        var quit = false
        h.controller.onQuit = { quit = true }
        menu.perform(.quit)
        XCTAssertTrue(quit)
    }
}
