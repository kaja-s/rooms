import CoreGraphics
import Foundation

/// Computes a frame for each window of an ordered list from a layout and the visible area of a screen.
/// All arithmetic is in AppKit screen coordinates (origin bottom-left, y up) and whole points.
public enum LayoutEngine {
    /// Gap between frames and between a frame and the area edge.
    public static let gap: CGFloat = 8
    /// Offset and shrink applied per window in the Stack layout.
    public static let stackStep: CGFloat = 32
    /// Tolerance per edge used when recognizing a tidy layout from actual frames.
    public static let recognitionTolerance: CGFloat = 24

    // MARK: Frames

    /// Frames for `count` windows in one of Focus, Columns, Grid, or Stack. Returns an empty array for Auto.
    public static func frames(for layout: Layout, count: Int, in area: CGRect) -> [CGRect] {
        guard count > 0 else { return [] }
        switch layout {
        case .focus: return focusFrames(count: count, in: area)
        case .columns: return columnFrames(count: count, in: area)
        case .grid: return gridFrames(count: count, in: area)
        case .stack: return stackFrames(count: count, in: area)
        case .auto: return []
        }
    }

    private static func integral(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x.rounded(), y: y.rounded(), width: max(1, w.rounded()), height: max(1, h.rounded()))
    }

    private static func focusFrames(count: Int, in area: CGRect) -> [CGRect] {
        let fullHeight = area.height - 2 * gap
        if count == 1 {
            return [integral(area.minX + gap, area.minY + gap, area.width - 2 * gap, fullHeight)]
        }
        let usableWidth = area.width - 3 * gap
        let mainWidth = (usableWidth * 2 / 3).rounded()
        let sideWidth = usableWidth - mainWidth
        var result = [integral(area.minX + gap, area.minY + gap, mainWidth, fullHeight)]
        let sideCount = count - 1
        let sideX = area.minX + gap + mainWidth + gap
        let usableHeight = area.height - CGFloat(sideCount + 1) * gap
        let sideHeight = (usableHeight / CGFloat(sideCount)).rounded(.down)
        for i in 0..<sideCount {
            let top = area.maxY - gap - CGFloat(i) * (sideHeight + gap)
            result.append(integral(sideX, top - sideHeight, sideWidth, sideHeight))
        }
        return result
    }

    private static func columnFrames(count: Int, in area: CGRect) -> [CGRect] {
        let width = ((area.width - CGFloat(count + 1) * gap) / CGFloat(count)).rounded(.down)
        let height = area.height - 2 * gap
        return (0..<count).map { i in
            integral(area.minX + gap + CGFloat(i) * (width + gap), area.minY + gap, width, height)
        }
    }

    private static func gridFrames(count: Int, in area: CGRect) -> [CGRect] {
        let columns = Int(Double(count).squareRoot().rounded(.up))
        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        let cellWidth = ((area.width - CGFloat(columns + 1) * gap) / CGFloat(columns)).rounded(.down)
        let cellHeight = ((area.height - CGFloat(rows + 1) * gap) / CGFloat(rows)).rounded(.down)
        return (0..<count).map { i in
            let row = i / columns
            let column = i % columns
            let x = area.minX + gap + CGFloat(column) * (cellWidth + gap)
            let top = area.maxY - gap - CGFloat(row) * (cellHeight + gap)
            return integral(x, top - cellHeight, cellWidth, cellHeight)
        }
    }

    private static func stackFrames(count: Int, in area: CGRect) -> [CGRect] {
        var result: [CGRect] = []
        var frame = integral(area.minX + gap, area.minY + gap, area.width - 2 * gap, area.height - 2 * gap)
        for i in 0..<count {
            if i > 0 {
                frame = integral(frame.minX + stackStep, frame.minY, frame.width - stackStep, frame.height - stackStep)
            }
            result.append(frame)
        }
        return result
    }

    // MARK: Fit

    /// A layout fits when its frames, adapted to the windows' minimum sizes, do not overlap; Stack always fits.
    public static func fits(_ layout: Layout, windows: [AppWindow], in area: CGRect) -> Bool {
        switch layout {
        case .stack, .auto:
            return true
        case .focus, .columns, .grid:
            return !adapt(layout, windows: windows, in: area).overlaps
        }
    }

    // MARK: Resolution

    /// Resolves Auto to a concrete layout: the first of Focus, Columns, Grid that fits, else Stack.
    public static func resolve(_ layout: Layout, windows: [AppWindow], in area: CGRect) -> Layout {
        guard layout == .auto else { return layout }
        return Layout.tidyLayouts.first { fits($0, windows: windows, in: area) } ?? .stack
    }

    /// Resolves the layout and returns the frames for the given windows, adapted to their minimum sizes.
    public static func frames(for windows: [AppWindow], layout: Layout, in area: CGRect) -> (layout: Layout, frames: [CGRect]) {
        let resolved = resolve(layout, windows: windows, in: area)
        return (resolved, adapt(resolved, windows: windows, in: area).frames)
    }

    /// The layouts a room cycles through with ⇥, in cycle order: every layout, whether or not it fits.
    public static var availableLayouts: [Layout] { Layout.cycleOrder }

    // MARK: Recognition

    /// The layouts ⌘S recognizes from current frames, in order.
    public static let recognizableLayouts: [Layout] = [.focus, .columns, .grid, .stack]

    /// Returns the first of Focus, Columns, Grid, Stack whose frames match the actual frames within `tolerance` on each edge, or nil.
    public static func recognize(frames actual: [CGRect], count: Int, in area: CGRect, tolerance: CGFloat = recognitionTolerance) -> Layout? {
        guard actual.count == count, count > 0 else { return nil }
        for candidate in recognizableLayouts {
            let expected = frames(for: candidate, count: count, in: area)
            let allClose = zip(actual, expected).allSatisfy { a, e in
                abs(a.minX - e.minX) <= tolerance && abs(a.maxX - e.maxX) <= tolerance &&
                abs(a.minY - e.minY) <= tolerance && abs(a.maxY - e.maxY) <= tolerance
            }
            if allClose { return candidate }
        }
        return nil
    }

    // MARK: Snapping keys

    public enum SnapPosition: Equatable {
        case leftHalf, rightHalf, topHalf, bottomHalf, fill
        case leftThird, rightThird, leftTwoThirds, rightTwoThirds
    }

    /// Frame for a snap position within the visible area, with the standard gap from the edges and the middle.
    public static func snapFrame(_ position: SnapPosition, in area: CGRect) -> CGRect {
        let fullHeight = area.height - 2 * gap
        let fullWidth = area.width - 2 * gap
        let halfWidth = ((area.width - 3 * gap) / 2).rounded(.down)
        let halfHeight = ((area.height - 3 * gap) / 2).rounded(.down)
        let thirdWidth = ((area.width - 4 * gap) / 3).rounded(.down)
        let twoThirdsWidth = thirdWidth * 2 + gap
        switch position {
        case .fill:
            return integral(area.minX + gap, area.minY + gap, fullWidth, fullHeight)
        case .leftHalf:
            return integral(area.minX + gap, area.minY + gap, halfWidth, fullHeight)
        case .rightHalf:
            return integral(area.maxX - gap - halfWidth, area.minY + gap, halfWidth, fullHeight)
        case .topHalf:
            return integral(area.minX + gap, area.maxY - gap - halfHeight, fullWidth, halfHeight)
        case .bottomHalf:
            return integral(area.minX + gap, area.minY + gap, fullWidth, halfHeight)
        case .leftThird:
            return integral(area.minX + gap, area.minY + gap, thirdWidth, fullHeight)
        case .rightThird:
            return integral(area.maxX - gap - thirdWidth, area.minY + gap, thirdWidth, fullHeight)
        case .leftTwoThirds:
            return integral(area.minX + gap, area.minY + gap, twoThirdsWidth, fullHeight)
        case .rightTwoThirds:
            return integral(area.maxX - gap - twoThirdsWidth, area.minY + gap, twoThirdsWidth, fullHeight)
        }
    }
}
