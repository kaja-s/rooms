import AppKit
import Foundation
import RoomsCore

/// A running application with standard windows.
public struct RunningApplication: Equatable, Hashable {
    public var bundleIdentifier: String
    public var processIdentifier: Int32
    public var name: String

    public init(bundleIdentifier: String, processIdentifier: Int32, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.name = name
    }
}

/// Every call the app makes to the Accessibility API, `NSRunningApplication`, screens, and window snapshots.
/// `AccessibilityWindowSystem` is the real implementation; `FakeWindowSystem` is the in-memory one for tests.
public protocol WindowSystem: AnyObject {
    var hasAccessibilityPermission: Bool { get }
    var hasScreenRecordingPermission: Bool { get }
    func openAccessibilitySettings()

    /// Running applications other than Rooms itself.
    func runningApplications() -> [RunningApplication]
    /// Standard windows of every running application except Rooms itself, including minimized windows and windows of hidden applications.
    func listWindows() -> [AppWindow]

    /// Visible area (screen minus menu bar and Dock) of the screen the mouse pointer is on, in AppKit coordinates.
    func currentScreenVisibleArea() -> CGRect
    func focusedWindow() -> WindowIdentity?

    func frame(of window: WindowIdentity) -> CGRect?
    func setFrame(_ frame: CGRect, of window: WindowIdentity)
    func setSize(_ size: CGSize, of window: WindowIdentity)
    func isMinimized(_ window: WindowIdentity) -> Bool
    func setMinimized(_ minimized: Bool, _ window: WindowIdentity)
    func raise(_ window: WindowIdentity)
    /// Activates the application, raises the window, and gives it keyboard focus.
    func focus(_ window: WindowIdentity)

    func isHidden(application processIdentifier: Int32) -> Bool
    func setHidden(_ hidden: Bool, application processIdentifier: Int32)

    func snapshot(of window: WindowIdentity) -> NSImage?
    func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage?

    /// Blocks the caller for the given time (used for the single frame retry).
    func wait(milliseconds: Int)
}
