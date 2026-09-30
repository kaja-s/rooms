import CoreGraphics
import Foundation

/// Finds saved windows again among the open windows.
public enum WindowMatcher {
    /// One entry per saved window: the open window it maps to, or nil when not found.
    /// Identity first; failing that, a window of the same application with the same title; failing that,
    /// the first window of the same application not matched by another saved window. Each open window is used at most once.
    public static func match(saved: [AppWindow], among open: [AppWindow]) -> [AppWindow?] {
        var result = [AppWindow?](repeating: nil, count: saved.count)
        var used = Set<Int>()

        func claim(_ savedIndex: Int, _ openIndex: Int) {
            result[savedIndex] = open[openIndex]
            used.insert(openIndex)
        }

        // Pass 1: exact identity.
        for (s, window) in saved.enumerated() {
            if let o = open.firstIndex(where: { !used.contains(open.firstIndex(of: $0)!) && $0.identity == window.identity }) {
                claim(s, o)
            }
        }
        // Pass 2: same application, same title.
        for (s, window) in saved.enumerated() where result[s] == nil {
            if let o = open.indices.first(where: { !used.contains($0) && open[$0].bundleIdentifier == window.bundleIdentifier && open[$0].title == window.title }) {
                claim(s, o)
            }
        }
        // Pass 3: first unmatched window of the same application.
        for (s, window) in saved.enumerated() where result[s] == nil {
            if let o = open.indices.first(where: { !used.contains($0) && open[$0].bundleIdentifier == window.bundleIdentifier }) {
                claim(s, o)
            }
        }
        return result
    }
}
