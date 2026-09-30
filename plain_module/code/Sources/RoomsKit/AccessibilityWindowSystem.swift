import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os
import RoomsCore

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

/// The real `WindowSystem`: Accessibility API for windows, `NSRunningApplication` for applications,
/// `CGWindowListCopyWindowInfo` for window ids and z-order, `CGWindowListCreateImage` for snapshots.
public final class AccessibilityWindowSystem: WindowSystem {
    private let logger = Logger(subsystem: "dev.rooms.app", category: "AccessibilityWindowSystem")
    private var elements: [WindowIdentity: AXUIElement] = [:]
    private let ownProcess = ProcessInfo.processInfo.processIdentifier

    public init() {}

    // MARK: Permissions

    public var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    public var hasScreenRecordingPermission: Bool { CGPreflightScreenCaptureAccess() }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Applications and windows

    public func runningApplications() -> [RunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownProcess }
            .map { RunningApplication(bundleIdentifier: $0.bundleIdentifier ?? "pid.\($0.processIdentifier)", processIdentifier: $0.processIdentifier, name: $0.localizedName ?? "") }
    }

    /// Window ids front to back, from the window server.
    private func zOrder() -> [CGWindowID: Int] {
        var order: [CGWindowID: Int] = [:]
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return order }
        for (index, info) in list.enumerated() {
            if let number = info[kCGWindowNumber as String] as? CGWindowID, order[number] == nil {
                order[number] = index
            }
        }
        return order
    }

    public func listWindows() -> [AppWindow] {
        var result: [AppWindow] = []
        elements.removeAll()
        for app in runningApplications() {
            for (identity, element) in standardWindows(of: app) {
                elements[identity] = element
                let title: String = copyAttribute(element, kAXTitleAttribute) ?? ""
                let frame = frame(ofElement: element) ?? .zero
                result.append(AppWindow(identity: identity, applicationName: app.name, title: title, frame: frame))
            }
        }
        let order = zOrder()
        return result.enumerated().sorted { a, b in
            let oa = order[a.element.identity.windowID] ?? Int.max
            let ob = order[b.element.identity.windowID] ?? Int.max
            if oa != ob { return oa < ob }
            return a.offset < b.offset
        }.map { $0.element }
    }

    private func standardWindows(of app: RunningApplication) -> [(WindowIdentity, AXUIElement)] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        var result: [(WindowIdentity, AXUIElement)] = []
        for element in windows {
            let role: String? = copyAttribute(element, kAXRoleAttribute)
            let subrole: String? = copyAttribute(element, kAXSubroleAttribute)
            guard role == kAXWindowRole as String, subrole == kAXStandardWindowSubrole as String else { continue }
            var windowID: CGWindowID = 0
            guard _AXUIElementGetWindow(element, &windowID) == .success, windowID != 0 else {
                logger.error("No window id for a window of \(app.name, privacy: .public); skipped")
                continue
            }
            let identity = WindowIdentity(bundleIdentifier: app.bundleIdentifier, processIdentifier: app.processIdentifier, windowID: windowID)
            result.append((identity, element))
        }
        return result
    }

    private func element(for identity: WindowIdentity) -> AXUIElement? {
        if let cached = elements[identity] { return cached }
        let app = RunningApplication(bundleIdentifier: identity.bundleIdentifier, processIdentifier: identity.processIdentifier, name: "")
        for (id, element) in standardWindows(of: app) {
            elements[id] = element
        }
        return elements[identity]
    }

    // MARK: Attributes

    private func copyAttribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value else { return nil }
        return value as? T
    }

    private func axValue(_ element: AXUIElement, _ name: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Accessibility positions are top-left based; AppKit frames are bottom-left based.
    private func appKitRect(fromAX position: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: position.x, y: primaryScreenHeight - position.y - size.height, width: size.width, height: size.height)
    }

    private func axPosition(fromAppKit frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX, y: primaryScreenHeight - frame.maxY)
    }

    private func frame(ofElement element: AXUIElement) -> CGRect? {
        guard let positionValue = axValue(element, kAXPositionAttribute), let sizeValue = axValue(element, kAXSizeAttribute) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position), AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return appKitRect(fromAX: position, size: size)
    }

    private func setPosition(_ point: CGPoint, of element: AXUIElement) {
        var p = point
        if let value = AXValueCreate(.cgPoint, &p) {
            let status = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
            if status != .success { logger.error("Set position failed: \(status.rawValue)") }
        }
    }

    private func setSize(_ size: CGSize, of element: AXUIElement) {
        var s = size
        if let value = AXValueCreate(.cgSize, &s) {
            let status = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
            if status != .success { logger.error("Set size failed: \(status.rawValue)") }
        }
    }

    // MARK: WindowSystem geometry

    public func currentScreenVisibleArea() -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? .zero
    }

    public func focusedWindow() -> WindowIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ownProcess else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success, let value else { return nil }
        let element = value as! AXUIElement
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &windowID) == .success else { return nil }
        let identity = WindowIdentity(bundleIdentifier: app.bundleIdentifier ?? "pid.\(app.processIdentifier)", processIdentifier: app.processIdentifier, windowID: windowID)
        elements[identity] = element
        return identity
    }

    public func frame(of window: WindowIdentity) -> CGRect? {
        guard let element = element(for: window) else { return nil }
        return frame(ofElement: element)
    }

    public func setFrame(_ frame: CGRect, of window: WindowIdentity) {
        guard let element = element(for: window) else {
            logger.error("setFrame: window \(window.windowID) not found; skipped")
            return
        }
        // Position, size, then position again so the window ends where it should even when the size changed.
        setPosition(axPosition(fromAppKit: frame), of: element)
        setSize(frame.size, of: element)
        setPosition(axPosition(fromAppKit: frame), of: element)
    }

    public func setSize(_ size: CGSize, of window: WindowIdentity) {
        guard let element = element(for: window) else { return }
        setSize(size, of: element)
    }

    public func isMinimized(_ window: WindowIdentity) -> Bool {
        guard let element = element(for: window) else { return false }
        let minimized: Bool? = copyAttribute(element, kAXMinimizedAttribute)
        return minimized ?? false
    }

    public func setMinimized(_ minimized: Bool, _ window: WindowIdentity) {
        guard let element = element(for: window) else { return }
        let status = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, (minimized ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef)
        if status != .success { logger.error("Set minimized failed for \(window.windowID): \(status.rawValue)") }
    }

    public func raise(_ window: WindowIdentity) {
        guard let element = element(for: window) else { return }
        let status = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        if status != .success { logger.error("Raise failed for \(window.windowID): \(status.rawValue)") }
    }

    public func focus(_ window: WindowIdentity) {
        guard let element = element(for: window) else { return }
        NSRunningApplication(processIdentifier: window.processIdentifier)?.activate()
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    // MARK: Full screen

    /// Applications with a window on a full-screen Space: a layer-0 window, not on the current Space, whose bounds
    /// equal a display's bounds. The Accessibility API does not list such a window from another Space.
    public func applicationsWithFullScreenWindows() -> Set<Int32> {
        let screens = displayBounds()
        let onScreen = Set(((CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? [])
            .compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        let all = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        var result = Set<Int32>()
        for info in all {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let number = info[kCGWindowNumber as String] as? CGWindowID, !onScreen.contains(number),
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo),
                  screens.contains(bounds.integral) else { continue }
            result.insert(pid)
        }
        return result
    }

    /// Applications with a window on another desktop: a layer-0 window of at least 100 by 100 points, not on the
    /// current Space, not in full screen, and not listed by the Accessibility API (minimized windows and windows of
    /// hidden applications are listed, so they are excluded).
    public func applicationsWithWindowsOnOtherDesktops() -> Set<Int32> {
        let screens = displayBounds()
        let listed = Set(listWindows().map { $0.identity.windowID })
        let onScreen = Set(((CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? [])
            .compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        let own = ProcessInfo.processInfo.processIdentifier
        let all = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        var result = Set<Int32>()
        for info in all {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  !onScreen.contains(number), !listed.contains(number),
                  let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != own,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo),
                  bounds.width >= 100, bounds.height >= 100,
                  !screens.contains(bounds.integral) else { continue }
            result.insert(pid)
        }
        return result
    }

    private func displayBounds() -> [CGRect] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays.map { CGDisplayBounds($0).integral }
    }

    /// Activates the application, which switches to its full-screen Space so the Accessibility API lists the window,
    /// and sets `AXFullScreen` to false on each of its full-screen windows.
    public func exitFullScreen(application processIdentifier: Int32) {
        guard let app = NSRunningApplication(processIdentifier: processIdentifier) else { return }
        app.activate()
        let running = RunningApplication(bundleIdentifier: app.bundleIdentifier ?? "pid.\(processIdentifier)", processIdentifier: processIdentifier, name: app.localizedName ?? "")
        for _ in 0..<15 {
            let fullScreen = standardWindows(of: running).filter { _, element in
                let value: Bool? = copyAttribute(element, "AXFullScreen")
                return value == true
            }
            if !fullScreen.isEmpty {
                for (identity, element) in fullScreen {
                    let status = AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, kCFBooleanFalse)
                    if status != .success { logger.error("Exit full screen failed for \(identity.windowID): \(status.rawValue)") }
                }
                return
            }
            wait(milliseconds: 100)
        }
        logger.error("No full-screen window found for \(running.name, privacy: .public)")
    }

    public func isHidden(application processIdentifier: Int32) -> Bool {
        NSRunningApplication(processIdentifier: processIdentifier)?.isHidden ?? false
    }

    public func setHidden(_ hidden: Bool, application processIdentifier: Int32) {
        guard let app = NSRunningApplication(processIdentifier: processIdentifier) else { return }
        if hidden { app.hide() } else { app.unhide() }
    }

    // MARK: Images

    public func snapshot(of window: WindowIdentity) -> NSImage? {
        guard hasScreenRecordingPermission else { return nil }
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, window.windowID, [.boundsIgnoreFraming, .bestResolution]) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    public func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }), let icon = app.icon {
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    public func wait(milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000)
    }
}
