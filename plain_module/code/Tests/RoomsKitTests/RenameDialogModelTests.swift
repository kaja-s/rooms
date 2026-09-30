import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class RenameDialogModelTests: XCTestCase {
    func testValidationAndConfirm() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a]), Room(name: "Deep Work", windows: [a])])
        let id = h.controller.rooms[0].id
        h.controller.beginRename(ofRoom: id)
        let dialog = h.controller.renameDialog!
        XCTAssertEqual(dialog.title, "Rename “Design”")
        XCTAssertEqual(dialog.text, "Design")
        XCTAssertEqual(dialog.cancelButtonTitle, "Cancel")
        XCTAssertEqual(dialog.renameButtonTitle, "Rename")
        XCTAssertTrue(dialog.isRenameEnabled)
        dialog.text = "deep work"
        XCTAssertFalse(dialog.isRenameEnabled)
        XCTAssertEqual(dialog.errorMessage, "A room with this name already exists")
        XCTAssertFalse(dialog.confirm())
        dialog.text = "   "
        XCTAssertFalse(dialog.isRenameEnabled)
        XCTAssertNil(dialog.errorMessage)
        dialog.text = "Design 2"
        XCTAssertTrue(dialog.confirm())
        XCTAssertNil(h.controller.renameDialog)
        XCTAssertEqual(h.reload()[0].name, "Design 2")
    }

    func testCancel() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "Design", windows: [a])])
        h.controller.beginRename(ofRoom: h.controller.rooms[0].id)
        h.controller.renameDialog?.text = "Other"
        h.controller.renameDialog?.cancel()
        XCTAssertNil(h.controller.renameDialog)
        XCTAssertEqual(h.controller.rooms[0].name, "Design")
    }
}
