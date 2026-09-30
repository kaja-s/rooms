import XCTest
@testable import RoomsCore

final class LayoutEngineTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func windows(_ count: Int, minWidth: CGFloat = 300, minHeight: CGFloat = 200) -> [AppWindow] {
        (0..<count).map { i in
            AppWindow(identity: WindowIdentity(bundleIdentifier: "a", processIdentifier: 1, windowID: UInt32(i)), applicationName: "A", title: "\(i)",
                      frame: CGRect(x: 0, y: 0, width: 500, height: 400), minimumSize: CGSize(width: minWidth, height: minHeight))
        }
    }

    func testFocusSingleWindowFillsArea() {
        XCTAssertEqual(LayoutEngine.frames(for: .focus, count: 1, in: area), [CGRect(x: 8, y: 8, width: 1424, height: 884)])
    }

    func testFocusThreeWindows() {
        let frames = LayoutEngine.frames(for: .focus, count: 3, in: area)
        XCTAssertEqual(frames[0], CGRect(x: 8, y: 8, width: 944, height: 884))
        XCTAssertEqual(frames[1], CGRect(x: 960, y: 454, width: 472, height: 438))
        XCTAssertEqual(frames[2], CGRect(x: 960, y: 8, width: 472, height: 438))
    }

    func testColumns() {
        let frames = LayoutEngine.frames(for: .columns, count: 3, in: area)
        XCTAssertEqual(frames.map { $0.minX }, [8, 485, 962])
        XCTAssertEqual(Set(frames.map { $0.width }), [469])
        XCTAssertEqual(Set(frames.map { $0.height }), [884])
    }

    func testGridFillsLeftToRightTopToBottom() {
        let frames = LayoutEngine.frames(for: .grid, count: 3, in: area)
        XCTAssertEqual(frames[0], CGRect(x: 8, y: 454, width: 708, height: 438))
        XCTAssertEqual(frames[1], CGRect(x: 724, y: 454, width: 708, height: 438))
        XCTAssertEqual(frames[2], CGRect(x: 8, y: 8, width: 708, height: 438))
    }

    func testGridFourWindowsIsTwoByTwo() {
        let frames = LayoutEngine.frames(for: .grid, count: 4, in: area)
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames[3], CGRect(x: 724, y: 8, width: 708, height: 438))
    }

    func testStackCascades() {
        let frames = LayoutEngine.frames(for: .stack, count: 3, in: area)
        XCTAssertEqual(frames[0], CGRect(x: 8, y: 8, width: 1424, height: 884))
        XCTAssertEqual(frames[1], CGRect(x: 40, y: 8, width: 1392, height: 852))
        XCTAssertEqual(frames[2], CGRect(x: 72, y: 8, width: 1360, height: 820))
        XCTAssertEqual(frames[1].maxY, frames[0].maxY - 32)
    }

    func testAutoHasNoFrames() {
        XCTAssertTrue(LayoutEngine.frames(for: .auto, count: 2, in: area).isEmpty)
    }

    func testFramesAreIntegral() {
        for layout in [Layout.focus, .columns, .grid, .stack] {
            for frame in LayoutEngine.frames(for: layout, count: 5, in: CGRect(x: 3.3, y: 2.2, width: 1001, height: 777)) {
                XCTAssertEqual(frame, frame.integral)
            }
        }
    }

    func testFits() {
        XCTAssertTrue(LayoutEngine.fits(.focus, windows: windows(3, minWidth: 400), in: area))
        XCTAssertFalse(LayoutEngine.fits(.focus, windows: windows(3, minWidth: 1000), in: area))
        XCTAssertTrue(LayoutEngine.fits(.stack, windows: windows(3, minWidth: 5000), in: area))
    }

    func testResolveAuto() {
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(3, minWidth: 400), in: area), .focus)
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(3, minWidth: 600), in: area), .focus, "Focus adapts without overlapping")
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(3, minWidth: 1000), in: area), .stack)
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(2, minWidth: 500, minHeight: 800), in: area), .focus)
        XCTAssertEqual(LayoutEngine.resolve(.auto, windows: windows(3, minWidth: 700, minHeight: 500), in: area), .stack, "no tidy layout fits without overlap")
    }

    func testAdaptLeavesPlainFramesWhenMinimumsFit() {
        let adaptation = LayoutEngine.adapt(.columns, windows: windows(3, minWidth: 400), in: area)
        XCTAssertFalse(adaptation.wasAdapted)
        XCTAssertEqual(adaptation.frames, LayoutEngine.frames(for: .columns, count: 3, in: area))
    }

    func testAdaptFocusGivesSideColumnItsMinimum() {
        let adaptation = LayoutEngine.adapt(.focus, windows: windows(3, minWidth: 600), in: area)
        XCTAssertTrue(adaptation.wasAdapted)
        XCTAssertFalse(adaptation.overlaps)
        XCTAssertEqual(adaptation.frames[1].width, 600)
        XCTAssertEqual(adaptation.frames[0].maxX + LayoutEngine.gap, adaptation.frames[1].minX)
        XCTAssertEqual(adaptation.frames[1].maxX, area.maxX - LayoutEngine.gap)
    }

    func testAdaptedFramesStayInsideAndNeverExceedTheArea() {
        for layout in [Layout.focus, .columns, .grid, .stack] {
            let adaptation = LayoutEngine.adapt(layout, windows: windows(4, minWidth: 5000, minHeight: 5000), in: area)
            for frame in adaptation.frames {
                XCTAssertTrue(area.insetBy(dx: LayoutEngine.gap, dy: LayoutEngine.gap).contains(frame), "\(layout) \(frame)")
            }
        }
    }

    func testAllocateSharesWhatIsLeft() {
        let result = LayoutEngine.allocate(mins: [700, 100, 100], weights: [1, 1, 1], length: 1424)
        XCTAssertEqual(result.sizes, [700, 354, 354])
        XCTAssertEqual(result.offsets, [0, 708, 1070])
        let overlapping = LayoutEngine.allocate(mins: [600, 600, 600], weights: [1, 1, 1], length: 1424)
        XCTAssertEqual(overlapping.offsets, [0, 412, 824])
    }

    func testAvailableLayoutsAreEveryLayout() {
        XCTAssertEqual(LayoutEngine.availableLayouts, [.auto, .focus, .columns, .grid, .stack])
    }

    func testRecognizeStack() {
        let stack = LayoutEngine.frames(for: .stack, count: 3, in: area)
        XCTAssertEqual(LayoutEngine.recognize(frames: stack.map { $0.offsetBy(dx: 10, dy: -10) }, count: 3, in: area), .stack)
    }

    func testRecognizeWithinTolerance() {
        var frames = LayoutEngine.frames(for: .columns, count: 3, in: area)
        frames[1] = frames[1].offsetBy(dx: 20, dy: -20)
        XCTAssertEqual(LayoutEngine.recognize(frames: frames, count: 3, in: area), .columns)
        frames[1] = frames[1].offsetBy(dx: 10, dy: 0)
        XCTAssertNil(LayoutEngine.recognize(frames: frames, count: 3, in: area))
        XCTAssertNil(LayoutEngine.recognize(frames: [], count: 0, in: area))
    }

    func testSnapFrames() {
        XCTAssertEqual(LayoutEngine.snapFrame(.leftHalf, in: area), CGRect(x: 8, y: 8, width: 708, height: 884))
        XCTAssertEqual(LayoutEngine.snapFrame(.rightHalf, in: area), CGRect(x: 724, y: 8, width: 708, height: 884))
        XCTAssertEqual(LayoutEngine.snapFrame(.topHalf, in: area), CGRect(x: 8, y: 454, width: 1424, height: 438))
        XCTAssertEqual(LayoutEngine.snapFrame(.bottomHalf, in: area), CGRect(x: 8, y: 8, width: 1424, height: 438))
        XCTAssertEqual(LayoutEngine.snapFrame(.fill, in: area), CGRect(x: 8, y: 8, width: 1424, height: 884))
        XCTAssertEqual(LayoutEngine.snapFrame(.leftThird, in: area), CGRect(x: 8, y: 8, width: 469, height: 884))
        XCTAssertEqual(LayoutEngine.snapFrame(.leftTwoThirds, in: area), CGRect(x: 8, y: 8, width: 946, height: 884))
        XCTAssertEqual(LayoutEngine.snapFrame(.rightThird, in: area).maxX, 1432)
        XCTAssertEqual(LayoutEngine.snapFrame(.rightTwoThirds, in: area).maxX, 1432)
    }
}
