import Foundation
import os
import RoomsCore

/// Lists the open windows of all running applications and finds saved windows again among them.
public final class WindowCatalog {
    public let system: WindowSystem
    private let logger = Logger(subsystem: "dev.rooms.app", category: "WindowCatalog")

    public init(system: WindowSystem) {
        self.system = system
    }

    /// Standard windows of every running application, or nil when Rooms lacks the Accessibility permission.
    public func listWindows() -> [AppWindow]? {
        guard system.hasAccessibilityPermission else {
            logger.error("Accessibility permission missing; cannot list windows")
            return nil
        }
        return system.listWindows()
    }

    /// Asks the window to resize to 1 by 1 point, reads the size the application allows, and restores the original frame.
    public func measureMinimumSize(of window: AppWindow) -> CGSize {
        guard let original = system.frame(of: window.identity) else {
            logger.error("Cannot measure minimum size: window \(window.identity.windowID) not found")
            return window.minimumSize
        }
        system.setSize(CGSize(width: 1, height: 1), of: window.identity)
        let settled = system.frame(of: window.identity)?.size ?? original.size
        system.setFrame(original, of: window.identity)
        return CGSize(width: settled.width.rounded(), height: settled.height.rounded())
    }

    /// Finds each saved window among the open windows; nil for a window that is not found.
    /// Found windows keep the saved minimum size and title fallback but carry the live identity and frame.
    public func find(_ saved: [AppWindow]) -> [AppWindow?] {
        let open = listWindows() ?? []
        return zip(saved, WindowMatcher.match(saved: saved, among: open)).map { savedWindow, found in
            guard var live = found else { return nil }
            live.minimumSize = savedWindow.minimumSize
            return live
        }
    }

    /// Moves a window to a frame. When the application does not apply it, requests it once more after 100 ms
    /// and accepts the frame the application settled on.
    @discardableResult
    public func move(_ window: WindowIdentity, to frame: CGRect) -> CGRect {
        system.setFrame(frame, of: window)
        guard let first = system.frame(of: window) else { return frame }
        if first.integral == frame.integral { return first }
        system.wait(milliseconds: 100)
        system.setFrame(frame, of: window)
        return system.frame(of: window) ?? first
    }

    public func currentFrame(of window: WindowIdentity) -> CGRect? {
        system.frame(of: window)
    }
}
