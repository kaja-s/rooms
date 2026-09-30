import CoreGraphics
import Foundation

/// Snaps a user's own arrangement to a grid with even gaps (My Layout).
public enum SnapGrid {
    public static let gridSize: CGFloat = 16
    public static let gap: CGFloat = LayoutEngine.gap

    /// Each frame's edges are snapped to a `gridSize` grid of the area, and windows whose edges are within
    /// `gridSize` of each other get exactly a `gap` between them.
    public static func snap(_ frames: [CGRect], in area: CGRect, gridSize: CGFloat = SnapGrid.gridSize, gap: CGFloat = SnapGrid.gap) -> [CGRect] {
        func snapX(_ v: CGFloat) -> CGFloat { area.minX + ((v - area.minX) / gridSize).rounded() * gridSize }
        func snapY(_ v: CGFloat) -> CGFloat { area.minY + ((v - area.minY) / gridSize).rounded() * gridSize }

        var edges: [(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)] = frames.map { f in
            var minX = max(area.minX, snapX(f.minX))
            var maxX = min(area.maxX, snapX(f.maxX))
            var minY = max(area.minY, snapY(f.minY))
            var maxY = min(area.maxY, snapY(f.maxY))
            if maxX - minX < gridSize { maxX = min(area.maxX, minX + gridSize); minX = maxX - gridSize }
            if maxY - minY < gridSize { maxY = min(area.maxY, minY + gridSize); minY = maxY - gridSize }
            return (minX, maxX, minY, maxY)
        }

        for a in edges.indices {
            for b in edges.indices where a != b {
                let verticalOverlap = min(edges[a].maxY, edges[b].maxY) > max(edges[a].minY, edges[b].minY)
                let horizontalOverlap = min(edges[a].maxX, edges[b].maxX) > max(edges[a].minX, edges[b].minX)
                if verticalOverlap && abs(edges[a].maxX - edges[b].minX) <= gridSize {
                    edges[b].minX = edges[a].maxX + gap
                }
                if horizontalOverlap && abs(edges[a].maxY - edges[b].minY) <= gridSize {
                    edges[b].minY = edges[a].maxY + gap
                }
            }
        }

        return edges.map { e in
            CGRect(x: e.minX.rounded(), y: e.minY.rounded(), width: max(1, (e.maxX - e.minX).rounded()), height: max(1, (e.maxY - e.minY).rounded()))
        }
    }
}
