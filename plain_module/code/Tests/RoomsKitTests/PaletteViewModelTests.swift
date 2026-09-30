import XCTest
@testable import RoomsCore
@testable import RoomsKit

final class PaletteViewModelTests: XCTestCase {
    private func seeded() -> (TestHarness, [Room]) {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let y = h.app("y", pid: 2, name: "Y")
        let a = h.window(x, id: 1, title: "A")
        let b = h.window(y, id: 2, title: "B")
        let c = h.window(x, id: 3, title: "C")
        let rooms = [
            Room(name: "Design", windows: [a, b], layout: .auto, createdAt: Date(timeIntervalSince1970: 1)),
            Room(name: "Deep Work", windows: [c], layout: .focus, directKey: 2, createdAt: Date(timeIntervalSince1970: 2)),
            Room(name: "Daily Build", windows: [a, c], layout: .grid, createdAt: Date(timeIntervalSince1970: 3), lastShown: Date(timeIntervalSince1970: 100)),
        ]
        h.seed(rooms)
        return (h, h.controller.rooms)
    }

    func testToggleOpenClose() {
        let (h, _) = seeded()
        let palette = h.controller.palette
        h.fake.visibleArea = CGRect(x: 10, y: 20, width: 1000, height: 700)
        h.controller.toggleHotkeyPressed()
        XCTAssertTrue(palette.isVisible)
        XCTAssertEqual(palette.query, "")
        XCTAssertEqual(palette.screenArea, h.fake.visibleArea)
        XCTAssertEqual(palette.selectedIndex, 0)
        h.controller.toggleHotkeyPressed()
        XCTAssertFalse(palette.isVisible)
        palette.open(); palette.pressEscape(); XCTAssertFalse(palette.isVisible)
        palette.open(); palette.clickedOutside(); XCTAssertFalse(palette.isVisible)
        h.controller.statusMenu.perform(.showPalette); XCTAssertTrue(palette.isVisible)
        XCTAssertTrue(palette.footerHints.contains(PaletteViewModel.returnHint))
        XCTAssertTrue(palette.footerHints.contains(PaletteViewModel.escapeHint))
    }

    func testRowsOrderAndContent() {
        let (h, rooms) = seeded()
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.rows.map { $0.title }, ["Daily Build", "Design", "Deep Work"])
        guard case .room(let row) = palette.rows[1] else { return XCTFail() }
        XCTAssertEqual(row.subtitle, "Auto · 2 windows")
        XCTAssertEqual(row.icons.count, 2)
        XCTAssertNil(row.trailer)
        guard case .room(let deep) = palette.rows[2] else { return XCTFail() }
        XCTAssertEqual(deep.trailer, "⌃⌥2")
        h.controller.showRoom(id: rooms[1].id)
        palette.open()
        guard case .room(let current) = palette.rows[0] else { return XCTFail() }
        XCTAssertEqual(current.name, "Deep Work")
        XCTAssertEqual(current.trailer, "Current")
        XCTAssertTrue(current.isCurrent)
    }

    func testSelectionMoves() {
        let (h, _) = seeded()
        let palette = h.controller.palette
        palette.open()
        palette.moveSelection(by: -1); XCTAssertEqual(palette.selectedIndex, 0)
        palette.moveSelection(by: 1); XCTAssertEqual(palette.selectedIndex, 1)
        palette.moveSelection(by: 5); XCTAssertEqual(palette.selectedIndex, 2)
        XCTAssertTrue(palette.rowShowsReturnAndDelete(at: 2))
        XCTAssertFalse(palette.rowShowsReturnAndDelete(at: 0))
    }

    func testEmptyState() {
        let h = TestHarness()
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.emptyStateText, PaletteViewModel.emptyStateText)
        XCTAssertTrue(palette.rows.isEmpty)
        XCTAssertNil(palette.preview)
        XCTAssertNil(palette.hereText)
        palette.query = "New"
        XCTAssertNil(palette.emptyStateText)
        XCTAssertEqual(palette.rows, [.create(name: "New")])
        XCTAssertTrue(palette.isCreateRowSelected)
    }

    func testFilterAndCreateRow() {
        let (h, _) = seeded()
        let palette = h.controller.palette
        palette.open()
        palette.query = "de"
        XCTAssertEqual(palette.rows.map { $0.title }, ["Design", "Deep Work", "Create “de”"])
        XCTAssertEqual(palette.selectedIndex, 0)
        palette.query = "design"
        XCTAssertEqual(palette.rows.map { $0.title }, ["Design"])
        palette.query = "zzz"
        XCTAssertEqual(palette.rows, [.create(name: "zzz")])
        XCTAssertTrue(palette.isCreateRowSelected)
        XCTAssertNil(palette.preview)
    }

    func testReturnShowsRoomOrStartsCreation() {
        let (h, rooms) = seeded()
        let palette = h.controller.palette
        palette.open()
        palette.pressReturn()
        XCTAssertFalse(palette.isVisible)
        XCTAssertEqual(h.controller.currentRoomID, rooms[2].id)
        palette.open()
        palette.query = "Alpha"
        palette.pressReturn()
        XCTAssertFalse(palette.isVisible)
        XCTAssertTrue(h.controller.picker.isPresented)
        XCTAssertEqual(h.controller.picker.mode, .create(name: "Alpha"))
        h.controller.picker.cancel()
        palette.open()
        palette.clickRow(1)
        XCTAssertEqual(h.controller.currentRoomID, rooms[0].id)
    }

    func testTabCyclesLayoutsAndFooter() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "R", windows: [a, b], layout: .auto)])
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.hereText, "Here: Focus")
        XCTAssertTrue(palette.footerHints.contains(PaletteViewModel.tabHint))
        var seen: [Layout] = []
        for _ in 0..<5 { palette.pressTab(); seen.append(h.controller.rooms[0].layout) }
        XCTAssertEqual(seen, [.focus, .columns, .grid, .stack, .auto])
        palette.pressTab(shift: true)
        XCTAssertEqual(h.controller.rooms[0].layout, .stack)
        XCTAssertEqual(palette.hereText, "Here: Stack")
        XCTAssertEqual(h.reload()[0].layout, .stack)
        XCTAssertEqual(palette.preview?.layout, .stack)
        XCTAssertEqual(palette.preview?.frames.count, 2)
    }

    func testTabSkipsLayoutsThatDoNotFit() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 1000, height: 100))
        let b = h.window(x, id: 2, title: "B", minimumSize: CGSize(width: 1000, height: 100))
        h.seed([Room(name: "R", windows: [a, b], layout: .auto, myLayoutFrames: [CGRect(x: 8, y: 8, width: 1000, height: 400), CGRect(x: 8, y: 450, width: 1000, height: 400)])])
        let palette = h.controller.palette
        palette.open()
        palette.pressTab(); XCTAssertEqual(h.controller.rooms[0].layout, .myLayout)
        palette.pressTab(); XCTAssertEqual(h.controller.rooms[0].layout, .stack)
        palette.pressTab(); XCTAssertEqual(h.controller.rooms[0].layout, .auto)
    }

    func testCommandKeys() {
        let (h, rooms) = seeded()
        let palette = h.controller.palette
        palette.open()
        palette.moveSelection(by: 1) // Design
        palette.pressCommandDigit(5)
        XCTAssertEqual(h.controller.room(rooms[0].id)?.directKey, 5)
        palette.pressCommandDigit(5)
        XCTAssertNil(h.controller.room(rooms[0].id)?.directKey)
        XCTAssertTrue(palette.footerHints.contains(PaletteViewModel.keyHint))
        XCTAssertTrue(palette.footerHints.contains(PaletteViewModel.rememberHint))
        palette.pressCommandS() // not current: nothing
        XCTAssertEqual(h.controller.room(rooms[0].id)?.layout, .auto)
        palette.pressCommandDelete()
        XCTAssertEqual(h.controller.rooms.count, 2)
        XCTAssertEqual(palette.rows.map { $0.title }, ["Daily Build", "Deep Work"])
        XCTAssertEqual(palette.selectedIndex, 1)
        palette.pressCommandDelete()
        XCTAssertEqual(palette.selectedIndex, 0)
    }

    func testDeleteButtonAndContextMenu() {
        let (h, rooms) = seeded()
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.contextMenuItems(forRow: 0).map { $0.title }, ["Edit Windows…", "Rename…", "Delete"])
        XCTAssertTrue(palette.contextMenuItems(forRow: 9).isEmpty)
        palette.performContextMenu(.rename, onRow: 1)
        XCTAssertEqual(h.controller.renameDialog?.roomID, rooms[0].id)
        h.controller.renameDialog?.cancel()
        palette.performContextMenu(.editWindows, onRow: 1)
        XCTAssertFalse(palette.isVisible)
        XCTAssertEqual(h.controller.picker.mode, .edit(roomID: rooms[0].id))
        h.controller.picker.cancel()
        palette.open()
        palette.performContextMenu(.delete, onRow: 2)
        XCTAssertEqual(h.controller.rooms.count, 2)
        palette.clickDeleteButton(0)
        XCTAssertEqual(h.controller.rooms.map { $0.name }, ["Design"])
    }

    func testPreviewOverlayAppearsAfterTabAndFollowsSelection() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "Xcode")
        let a = h.window(x, id: 1, title: "Main.swift", minimumSize: CGSize(width: 100, height: 100))
        let b = h.window(x, id: 2, title: "Tests", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "One", windows: [a], layout: .focus, createdAt: Date(timeIntervalSince1970: 1)),
                Room(name: "Two", windows: [a, b], layout: .columns, createdAt: Date(timeIntervalSince1970: 2))])
        let palette = h.controller.palette
        palette.open()
        XCTAssertFalse(palette.isPreviewVisible)
        XCTAssertNil(palette.preview)
        palette.pressTab()
        XCTAssertTrue(palette.isPreviewVisible)
        let preview = palette.preview!
        XCTAssertEqual(preview.area, h.fake.visibleArea)
        XCTAssertEqual(preview.layout, .columns)
        XCTAssertEqual(preview.cards.map { $0.id }, [a.identity])
        XCTAssertEqual(preview.cards[0].applicationName, "Xcode")
        XCTAssertEqual(preview.cards[0].title, "Main.swift")
        XCTAssertNotNil(preview.cards[0].icon)
        palette.moveSelection(by: 1)
        XCTAssertEqual(palette.preview?.cards.map { $0.title }, ["Main.swift", "Tests"])
        XCTAssertEqual(palette.preview?.frames, LayoutEngine.frames(for: .columns, count: 2, in: h.fake.visibleArea))
        palette.query = "new room"
        XCTAssertNil(palette.preview, "hidden while the Create row is selected")
        palette.close()
        XCTAssertFalse(palette.isPreviewVisible)
        palette.open()
        XCTAssertNil(palette.preview)
        XCTAssertEqual(LayoutPreview.animationDuration, 0.2)
    }

    func testRowTrailingElementsAndSections() {
        let h = TestHarness()
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A")
        h.seed([Room(name: "One", windows: [a], directKey: 1, createdAt: Date(timeIntervalSince1970: 1)),
                Room(name: "Two", windows: [a], directKey: 2, createdAt: Date(timeIntervalSince1970: 2)),
                Room(name: "Three", windows: [a], createdAt: Date(timeIntervalSince1970: 3))])
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.rowTrailingElements(at: 0), ["⌃⌥1", "↵", "ⓧ"])
        XCTAssertEqual(palette.rowTrailingElements(at: 1), ["⌃⌥2"])
        XCTAssertEqual(palette.rowTrailingElements(at: 2), [])
        palette.moveSelection(by: 2)
        XCTAssertEqual(palette.rowTrailingElements(at: 2), ["↵", "ⓧ"])
        XCTAssertEqual(palette.rowTrailingElements(at: 9), [])
        XCTAssertEqual(PaletteDesign.sections, [.searchField, .divider, .list, .keyHints])
        XCTAssertEqual(PaletteDesign.panelWidth, 640)
        XCTAssertEqual(PaletteDesign.rowHeight, 64)
    }
}


extension PaletteViewModelTests {
    func testFooterGroupsWithAndWithoutSelectedRoom() {
        let h = TestHarness()
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.leadingFooterHints, ["⇥ Layout", "⌘S Remember mine", "⌘1–9 Key"])
        XCTAssertEqual(palette.trailingFooterHints, ["↵ Go", "esc Close"])
        XCTAssertEqual(palette.footerHints, palette.leadingFooterHints + palette.trailingFooterHints)
        let x = h.app("x", pid: 1, name: "X")
        let a = h.window(x, id: 1, title: "A", minimumSize: CGSize(width: 100, height: 100))
        h.seed([Room(name: "R", windows: [a], layout: .auto)])
        palette.open()
        XCTAssertEqual(palette.leadingFooterHints.first, "Here: Focus")
        XCTAssertTrue(PaletteViewModel.tabHint.hasPrefix("⇥"))
    }

    func testPanelHeightFollowsRows() {
        let (h, _) = seeded()
        let palette = h.controller.palette
        palette.open()
        XCTAssertEqual(palette.panelHeight, PaletteDesign.panelHeight(rowCount: 3))
        XCTAssertEqual(palette.panelHeight, 349)
        palette.query = "Deep"
        XCTAssertEqual(palette.panelHeight, PaletteDesign.panelHeight(rowCount: palette.rows.count))
        palette.query = ""
        XCTAssertEqual(palette.panelHeight, 349)
    }

    func testPanelHeightOfEmptyStateUsesEmptyBlock() {
        XCTAssertEqual(PaletteDesign.panelHeight(rowCount: 0),
                       PaletteDesign.panelHeight(rowCount: 1) - PaletteDesign.rowHeight + PaletteDesign.emptyStateHeight)
    }
}
