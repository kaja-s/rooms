import XCTest
@testable import RoomsKit

final class GettingStartedModelTests: XCTestCase {
    func testContentAndDone() {
        let h = TestHarness()
        h.fake.visibleArea = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let model = h.controller.gettingStarted
        XCTAssertFalse(model.isPresented)
        h.controller.openGettingStarted()
        XCTAssertTrue(model.isPresented)
        XCTAssertEqual(model.screenArea, h.fake.visibleArea)
        XCTAssertEqual(model.title, "Getting Started")
        XCTAssertEqual(model.steps, [
            "Open the windows a project needs.",
            "Press ⌥Space, type a name for the room, and press ↵.",
            "Click the windows that belong in it; the number on a card is its place, and 1 is the main window. Then Create Room.",
            "Press ⇥ in ⌥Space to change the layout.",
        ])
        XCTAssertEqual(model.footerText, "From then on, ⌥Space and the room's name, or ⌃⌥1–9, brings it back.")
        XCTAssertEqual(model.doneButtonTitle, "Done")
        model.done()
        XCTAssertFalse(model.isPresented)
    }
}
