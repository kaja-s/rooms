import AppKit
import Foundation
import RoomsCore

/// In-memory `WindowSystem` whose applications, windows, screens, permission flags, and recorded operations
/// are set and read directly by test code.
public final class FakeWindowSystem: WindowSystem {
    public struct Window: Equatable {
        public var identity: WindowIdentity
        public var applicationName: String
        public var title: String
        public var frame: CGRect
        public var minimumSize: CGSize
        public var isMinimized: Bool
        public var isStandard: Bool
        public var isRoomsOwn: Bool
        /// Milliseconds on the fake clock before a requested frame or size is applied; 0 applies it at once.
        public var resizeDelayMilliseconds = 0
        /// When set, size changes are ignored; only the origin of a requested frame is applied.
        public var ignoresResize = false
        /// A full-screen window is not listed, like the Accessibility API on another Space.
        public var isFullScreen = false
        /// A window on another desktop is not listed, like the Accessibility API.
        public var isOnOtherDesktop = false
        var pending: (frame: CGRect, at: Int)?

        public static func == (lhs: Window, rhs: Window) -> Bool {
            lhs.identity == rhs.identity && lhs.applicationName == rhs.applicationName && lhs.title == rhs.title
                && lhs.frame == rhs.frame && lhs.minimumSize == rhs.minimumSize && lhs.isMinimized == rhs.isMinimized
                && lhs.isStandard == rhs.isStandard && lhs.isRoomsOwn == rhs.isRoomsOwn
                && lhs.resizeDelayMilliseconds == rhs.resizeDelayMilliseconds && lhs.ignoresResize == rhs.ignoresResize
                && lhs.isFullScreen == rhs.isFullScreen && lhs.isOnOtherDesktop == rhs.isOnOtherDesktop
        }

        public init(identity: WindowIdentity, applicationName: String, title: String, frame: CGRect, minimumSize: CGSize = .zero, isMinimized: Bool = false, isStandard: Bool = true, isRoomsOwn: Bool = false) {
            self.identity = identity
            self.applicationName = applicationName
            self.title = title
            self.frame = frame
            self.minimumSize = minimumSize
            self.isMinimized = isMinimized
            self.isStandard = isStandard
            self.isRoomsOwn = isRoomsOwn
        }
    }

    public enum Operation: Equatable {
        case setFrame(WindowIdentity, CGRect)
        case setSize(WindowIdentity, CGSize)
        case raise(WindowIdentity)
        case focus(WindowIdentity)
        case minimize(WindowIdentity)
        case unminimize(WindowIdentity)
        case hide(Int32)
        case unhide(Int32)
        case exitFullScreen(Int32)
        case openAccessibilitySettings
    }

    public var applications: [RunningApplication] = []
    public var windows: [Window] = []
    public var hiddenApplications: Set<Int32> = []
    public var accessibilityPermission = true
    public var screenRecordingPermission = true
    public var visibleArea = CGRect(x: 0, y: 0, width: 1440, height: 900)
    public var focusedWindowIdentity: WindowIdentity?
    public private(set) var operations: [Operation] = []
    public var snapshotImage: NSImage? = NSImage(size: NSSize(width: 4, height: 3))
    public var iconImage: NSImage? = NSImage(size: NSSize(width: 16, height: 16))
    public private(set) var waitedMilliseconds = 0

    public init() {}

    // MARK: Test helpers

    @discardableResult
    public func addApplication(bundleIdentifier: String, processIdentifier: Int32, name: String) -> RunningApplication {
        let app = RunningApplication(bundleIdentifier: bundleIdentifier, processIdentifier: processIdentifier, name: name)
        applications.append(app)
        return app
    }

    @discardableResult
    public func addWindow(of app: RunningApplication, windowID: UInt32, title: String, frame: CGRect, minimumSize: CGSize = .zero, isMinimized: Bool = false, isStandard: Bool = true, isRoomsOwn: Bool = false) -> WindowIdentity {
        let identity = WindowIdentity(bundleIdentifier: app.bundleIdentifier, processIdentifier: app.processIdentifier, windowID: windowID)
        windows.append(Window(identity: identity, applicationName: app.name, title: title, frame: frame, minimumSize: minimumSize, isMinimized: isMinimized, isStandard: isStandard, isRoomsOwn: isRoomsOwn))
        return identity
    }

    /// Makes a window's application apply resizes after `delayMilliseconds` on the fake clock, or ignore them.
    public func setResizeBehavior(of identity: WindowIdentity, delayMilliseconds: Int = 0, ignoresResize: Bool = false) {
        guard let i = index(of: identity) else { return }
        windows[i].resizeDelayMilliseconds = delayMilliseconds
        windows[i].ignoresResize = ignoresResize
    }

    /// Puts a window in or out of full screen.
    public func setFullScreen(_ fullScreen: Bool, of identity: WindowIdentity) {
        guard let i = index(of: identity) else { return }
        windows[i].isFullScreen = fullScreen
    }

    /// Moves a window to another desktop, or back to the current one.
    public func setOnOtherDesktop(_ onOther: Bool, of identity: WindowIdentity) {
        guard let i = index(of: identity) else { return }
        windows[i].isOnOtherDesktop = onOther
    }

    public func applicationsWithWindowsOnOtherDesktops() -> Set<Int32> {
        Set(windows.filter { $0.isOnOtherDesktop && !$0.isFullScreen }.map { $0.identity.processIdentifier })
    }

    public func applicationsWithFullScreenWindows() -> Set<Int32> {
        Set(windows.filter { $0.isFullScreen }.map { $0.identity.processIdentifier })
    }

    public func exitFullScreen(application processIdentifier: Int32) {
        operations.append(.exitFullScreen(processIdentifier))
        for i in windows.indices where windows[i].identity.processIdentifier == processIdentifier {
            windows[i].isFullScreen = false
        }
    }

    /// Removes the application and all its windows.
    public func quitApplication(processIdentifier: Int32) {
        applications.removeAll { $0.processIdentifier == processIdentifier }
        windows.removeAll { $0.identity.processIdentifier == processIdentifier }
        hiddenApplications.remove(processIdentifier)
    }

    public func clearOperations() { operations.removeAll() }

    public func window(_ identity: WindowIdentity) -> Window? {
        windows.first { $0.identity == identity }
    }

    public var raiseOrder: [WindowIdentity] {
        operations.compactMap { if case .raise(let id) = $0 { return id } else { return nil } }
    }

    public var focusedByOperation: WindowIdentity? {
        operations.reversed().compactMap { if case .focus(let id) = $0 { return id } else { return nil } }.first
    }

    private func index(of identity: WindowIdentity) -> Int? {
        windows.firstIndex { $0.identity == identity }
    }

    // MARK: WindowSystem

    public var hasAccessibilityPermission: Bool { accessibilityPermission }
    public var hasScreenRecordingPermission: Bool { screenRecordingPermission }

    public func openAccessibilitySettings() { operations.append(.openAccessibilitySettings) }

    public func runningApplications() -> [RunningApplication] { applications }

    public func listWindows() -> [AppWindow] {
        windows.filter { $0.isStandard && !$0.isRoomsOwn && !$0.isFullScreen && !$0.isOnOtherDesktop }.map {
            AppWindow(identity: $0.identity, applicationName: $0.applicationName, title: $0.title, frame: $0.frame, minimumSize: .zero)
        }
    }

    public func currentScreenVisibleArea() -> CGRect { visibleArea }

    public func focusedWindow() -> WindowIdentity? { focusedWindowIdentity }

    public func frame(of window: WindowIdentity) -> CGRect? { self.window(window)?.frame }

    public func setFrame(_ frame: CGRect, of window: WindowIdentity) {
        operations.append(.setFrame(window, frame))
        guard let i = index(of: window) else { return }
        request(frame, forWindowAt: i)
    }

    public func setSize(_ size: CGSize, of window: WindowIdentity) {
        operations.append(.setSize(window, size))
        guard let i = index(of: window) else { return }
        let base = windows[i].pending?.frame ?? windows[i].frame
        request(CGRect(origin: base.origin, size: size), forWindowAt: i)
    }

    /// Applies a requested frame the way the window's application would: clamped to its minimum size,
    /// without resizing when it ignores resizes, and after its resize delay on the fake clock.
    private func request(_ frame: CGRect, forWindowAt i: Int) {
        var applied = frame
        if windows[i].ignoresResize {
            applied.size = windows[i].frame.size
        } else {
            applied.size.width = max(frame.width, windows[i].minimumSize.width)
            applied.size.height = max(frame.height, windows[i].minimumSize.height)
        }
        if windows[i].resizeDelayMilliseconds > 0 {
            windows[i].pending = (applied, waitedMilliseconds + windows[i].resizeDelayMilliseconds)
        } else {
            windows[i].pending = nil
            windows[i].frame = applied
        }
    }

    private func applyDueRequests() {
        for i in windows.indices {
            if let pending = windows[i].pending, pending.at <= waitedMilliseconds {
                windows[i].frame = pending.frame
                windows[i].pending = nil
            }
        }
    }

    public func isMinimized(_ window: WindowIdentity) -> Bool { self.window(window)?.isMinimized ?? false }

    public func setMinimized(_ minimized: Bool, _ window: WindowIdentity) {
        operations.append(minimized ? .minimize(window) : .unminimize(window))
        guard let i = index(of: window) else { return }
        windows[i].isMinimized = minimized
    }

    public func raise(_ window: WindowIdentity) { operations.append(.raise(window)) }

    public func focus(_ window: WindowIdentity) {
        operations.append(.focus(window))
        focusedWindowIdentity = window
    }

    public func isHidden(application processIdentifier: Int32) -> Bool { hiddenApplications.contains(processIdentifier) }

    public func setHidden(_ hidden: Bool, application processIdentifier: Int32) {
        operations.append(hidden ? .hide(processIdentifier) : .unhide(processIdentifier))
        if hidden { hiddenApplications.insert(processIdentifier) } else { hiddenApplications.remove(processIdentifier) }
    }

    public func snapshot(of window: WindowIdentity) -> NSImage? { screenRecordingPermission ? snapshotImage : nil }

    public func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? { iconImage }

    public func wait(milliseconds: Int) {
        waitedMilliseconds += milliseconds
        applyDueRequests()
    }
}
