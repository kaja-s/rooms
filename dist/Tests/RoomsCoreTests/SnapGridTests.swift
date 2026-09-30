import XCTest
@testable import RoomsCore

final class SnapGridTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testEdgesSnapToGrid() {
        let snapped = SnapGrid.snap([CGRect(x: 13, y: 21, width: 300, height: 200)], in: area)
        XCTAssertEqual(snapped, [CGRect(x: 16, y: 16, width: 304, height: 208)])
    }

    func testNeighboursGetExactGap() {
        let a = CGRect(x: 0, y: 0, width: 400, height: 400)
        let b = CGRect(x: 410, y: 0, width: 400, height: 400)
        let snapped = SnapGrid.snap([a, b], in: area)
        XCTAssertEqual(snapped[1].minX, snapped[0].maxX + 8)
        XCTAssertEqual(snapped[1].maxX, 816)
    }

    func testVerticalNeighboursGetExactGap() {
        let a = CGRect(x: 0, y: 0, width: 400, height: 400)
        let b = CGRect(x: 0, y: 412, width: 400, height: 300)
        let snapped = SnapGrid.snap([a, b], in: area)
        XCTAssertEqual(snapped[1].minY, snapped[0].maxY + 8)
    }

    func testFramesStayInsideArea() {
        let snapped = SnapGrid.snap([CGRect(x: -20, y: -30, width: 2000, height: 2000)], in: area)
        XCTAssertEqual(snapped, [area])
    }

    func testFarApartWindowsAreUntouched() {
        let snapped = SnapGrid.snap([CGRect(x: 0, y: 0, width: 400, height: 400), CGRect(x: 800, y: 0, width: 400, height: 400)], in: area)
        XCTAssertEqual(snapped[1].minX, 800)
    }
}
