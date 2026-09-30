import AppKit
import Combine
import Foundation
import os
import RoomsCore

/// Facade owning the room store, the current room, the window system, and one view model per surface.
public final class AppController: ObservableObject {
    public static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    public let store: RoomStore
    public let windowSystem: WindowSystem
    public let catalog: WindowCatalog
    public let defaults: UserDefaults
    private let logger = Logger(subsystem: "dev.rooms.app", category: "AppController")

    @Published public private(set) var rooms: [Room] = []
    @Published public private(set) var currentRoomID: UUID?
    /// The most recent notification message shown to the user.
    @Published public private(set) var notificationMessage: String?
    public private(set) var notificationHistory: [String] = []
    @Published public private(set) var permissionDialog: PermissionDialogModel?
    @Published public private(set) var renameDialog: RenameDialogModel?
    public private(set) var quitRequested = false
    /// Called when the user chooses Quit Rooms.
    public var onQuit: () -> Void = {}

    private var _palette: PaletteViewModel!
    private var _picker: WindowPickerViewModel!
    private var _statusMenu: StatusMenuModel!
    public var palette: PaletteViewModel { _palette }
    public var picker: WindowPickerViewModel { _picker }
    public var statusMenu: StatusMenuModel { _statusMenu }
    public let gettingStarted = GettingStartedModel()

    public enum SnapKey: Equatable { case left, right, up, down, fill }
    private var snapStates: [WindowIdentity: (position: LayoutEngine.SnapPosition, frame: CGRect)] = [:]

    public init(store: RoomStore = RoomStore(), windowSystem: WindowSystem, defaults: UserDefaults = .standard) {
        self.store = store
        self.windowSystem = windowSystem
        self.catalog = WindowCatalog(system: windowSystem)
        self.defaults = defaults
        _palette = PaletteViewModel(controller: self)
        _picker = WindowPickerViewModel(controller: self)
        _statusMenu = StatusMenuModel(controller: self)
    }

    /// Loads the room list and opens Getting Started on the first launch.
    public func start() {
        rooms = store.load()
        if !defaults.bool(forKey: AppController.hasLaunchedBeforeKey) {
            defaults.set(true, forKey: AppController.hasLaunchedBeforeKey)
            openGettingStarted()
        }
    }

    // MARK: Rooms

    public var currentRoom: Room? {
        guard let id = currentRoomID else { return nil }
        return room(id)
    }

    public func room(_ id: UUID) -> Room? {
        rooms.first { $0.id == id }
    }

    private func update(_ id: UUID, _ change: (inout Room) -> Void) {
        guard let index = rooms.firstIndex(where: { $0.id == id }) else { return }
        change(&rooms[index])
    }

    private func persist() {
        do {
            try store.save(rooms)
        } catch {
            logger.error("Failed to save rooms: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func notify(_ message: String) {
        notificationMessage = message
        notificationHistory.append(message)
    }

    // MARK: Hotkeys

    /// ⌥Space
    public func toggleHotkeyPressed() {
        palette.toggle()
    }

    /// ⌃⌥1–9: shows the room with that direct key; nothing happens when no room has it.
    public func directKeyPressed(_ key: Int) {
        guard let room = rooms.first(where: { $0.directKey == key }) else { return }
        showRoom(id: room.id)
    }

    /// ⌃⌥ arrows and ⌃⌥↩ move the focused window to a half, a third, two thirds, or the whole visible area.
    public func snapKeyPressed(_ key: SnapKey) {
        guard let window = windowSystem.focusedWindow() else { return }
        let area = windowSystem.currentScreenVisibleArea()
        let current = windowSystem.frame(of: window)
        var position: LayoutEngine.SnapPosition
        switch key {
        case .left: position = .leftHalf
        case .right: position = .rightHalf
        case .up: position = .topHalf
        case .down: position = .bottomHalf
        case .fill: position = .fill
        }
        if let last = snapStates[window], let current, last.frame.integral == current.integral {
            let leftCycle: [LayoutEngine.SnapPosition] = [.leftHalf, .leftThird, .leftTwoThirds]
            let rightCycle: [LayoutEngine.SnapPosition] = [.rightHalf, .rightThird, .rightTwoThirds]
            if key == .left, let i = leftCycle.firstIndex(of: last.position) {
                position = leftCycle[(i + 1) % leftCycle.count]
            } else if key == .right, let i = rightCycle.firstIndex(of: last.position) {
                position = rightCycle[(i + 1) % rightCycle.count]
            }
        }
        let frame = LayoutEngine.snapFrame(position, in: area)
        let applied = catalog.move(window, to: frame)
        snapStates[window] = (position, applied)
    }

    // MARK: Permission

    /// Lists windows, or shows the Accessibility dialog and returns nil.
    private func listWindowsOrPrompt() -> [AppWindow]? {
        if let windows = catalog.listWindows() { return windows }
        permissionDialog = PermissionDialogModel()
        return nil
    }

    public func permissionDialogOpenSettings() {
        windowSystem.openAccessibilitySettings()
        permissionDialog = nil
    }

    public func permissionDialogCancel() {
        permissionDialog = nil
    }

    // MARK: Create / edit

    /// Opens the window picker for a new room with the typed name.
    public func beginCreateRoom(named name: String) {
        guard let windows = listWindowsOrPrompt() else { return }
        picker.present(mode: .create(name: name), windows: windows, preselected: [])
    }

    /// Create Room: saves the room (layout Auto, no direct key), then shows it.
    public func createRoom(named name: String, windows selected: [AppWindow]) {
        guard !selected.isEmpty else { return }
        let measured = selected.map { window -> AppWindow in
            var w = window
            w.minimumSize = catalog.measureMinimumSize(of: window)
            return w
        }
        let room = Room(name: name, windows: measured, layout: .auto)
        rooms.append(room)
        persist()
        showRoom(id: room.id)
    }

    /// Opens the window picker for an existing room with its found windows preselected in room order.
    public func beginEditWindows(ofRoom id: UUID) {
        guard let room = room(id), let windows = listWindowsOrPrompt() else { return }
        let found = WindowMatcher.match(saved: room.windows, among: windows).compactMap { $0?.identity }
        picker.present(mode: .edit(roomID: id), windows: windows, preselected: found)
    }

    /// Save Room: replaces the windows and measures them again.
    public func replaceWindows(ofRoom id: UUID, with selected: [AppWindow]) {
        guard room(id) != nil, !selected.isEmpty else { return }
        let measured = selected.map { window -> AppWindow in
            var w = window
            w.minimumSize = catalog.measureMinimumSize(of: window)
            return w
        }
        update(id) { $0.windows = measured }
        persist()
        if currentRoomID == id { showRoom(id: id) }
    }

    // MARK: Show

    private struct FoundWindow {
        var index: Int
        var window: AppWindow
    }

    private func foundWindows(of room: Room, among open: [AppWindow]) -> [FoundWindow] {
        zip(room.windows.indices, WindowMatcher.match(saved: room.windows, among: open)).compactMap { index, live in
            guard var live else { return nil }
            live.minimumSize = room.windows[index].minimumSize
            return FoundWindow(index: index, window: live)
        }
    }

    private func layoutFrames(for room: Room, found: [FoundWindow], in area: CGRect) -> (Layout, [CGRect]) {
        LayoutEngine.frames(for: found.map { $0.window }, layout: room.layout, in: area)
    }

    /// Shows a room: lays its found windows out on the current screen, hides everything else, and makes it current.
    public func showRoom(id: UUID) {
        guard let room = room(id) else { return }
        palette.close()
        guard let open = listWindowsOrPrompt() else { return }
        let found = foundWindows(of: room, among: open)
        let missing = missingApplications(of: room, found: found)
        guard missing.isEmpty else {
            notify("Open \(Self.joinedNames(missing)), then open “\(room.name)” again")
            return
        }
        let area = windowSystem.currentScreenVisibleArea()
        let (_, frames) = layoutFrames(for: room, found: found, in: area)

        // Unhide applications of the room, unminimize, move, and raise each found window.
        let roomProcesses = Set(found.map { $0.window.processIdentifier })
        for pid in roomProcesses where windowSystem.isHidden(application: pid) {
            windowSystem.setHidden(false, application: pid)
        }
        for (position, item) in found.enumerated() {
            let identity = item.window.identity
            if windowSystem.isMinimized(identity) { windowSystem.setMinimized(false, identity) }
            catalog.move(identity, to: frames[position])
            windowSystem.raise(identity)
        }

        // Hide every window that is not in the room.
        let foundIdentities = Set(found.map { $0.window.identity })
        for app in windowSystem.runningApplications() where !roomProcesses.contains(app.processIdentifier) {
            if !windowSystem.isHidden(application: app.processIdentifier) {
                windowSystem.setHidden(true, application: app.processIdentifier)
            }
        }
        for window in open where roomProcesses.contains(window.processIdentifier) && !foundIdentities.contains(window.identity) {
            if !windowSystem.isMinimized(window.identity) { windowSystem.setMinimized(true, window.identity) }
        }

        // The main window, or the first found window, is raised last and gets keyboard focus.
        let main = found.first { $0.index == 0 } ?? found[0]
        windowSystem.raise(main.window.identity)
        windowSystem.focus(main.window.identity)

        currentRoomID = id
        update(id) { $0.lastShown = Date() }
        persist()
    }

    /// Moves the found windows of the current room to the frames of its (possibly new) layout, without hiding or focusing.
    private func relayoutCurrentRoom() {
        guard let room = currentRoom, let open = catalog.listWindows() else { return }
        let found = foundWindows(of: room, among: open)
        guard !found.isEmpty else { return }
        let (_, frames) = layoutFrames(for: room, found: found, in: windowSystem.currentScreenVisibleArea())
        for (position, item) in found.enumerated() {
            catalog.move(item.window.identity, to: frames[position])
        }
    }

    // MARK: Layout

    public func setLayout(_ layout: Layout, ofRoom id: UUID) {
        update(id) { $0.layout = layout }
        persist()
        if currentRoomID == id { relayoutCurrentRoom() }
    }

    /// ⌘S: recognizes a tidy layout from the current arrangement, or saves it as My Layout. Only for the current room.
    /// Names of the applications of the room's windows that were not found (the application quit or the window was
    /// closed), in room order, each once.
    private func missingApplications(of room: Room, found: [FoundWindow]) -> [String] {
        let foundIndices = Set(found.map { $0.index })
        var names: [String] = []
        for (index, window) in room.windows.enumerated() where !foundIndices.contains(index) && !names.contains(window.applicationName) {
            names.append(window.applicationName)
        }
        return names
    }

    /// "A", "A and B", "A, B and C".
    static func joinedNames(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    // MARK: Save visible windows (⌘S)

    /// The windows visible on the current screen, front to back: not minimized and not of a hidden application.
    private func visibleWindows(in area: CGRect) -> [AppWindow] {
        (catalog.listWindows() ?? []).filter { window in
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            return area.contains(center)
                && !windowSystem.isMinimized(window.identity)
                && !windowSystem.isHidden(application: window.processIdentifier)
        }
    }

    /// "Room <n>" with the smallest n of 1 or more that no room uses, ignoring case.
    public func nextDefaultRoomName() -> String {
        var n = 1
        while RoomMatcher.hasRoom(named: "Room \(n)", in: rooms) { n += 1 }
        return "Room \(n)"
    }

    /// ⌘S: saves the windows visible on the current screen as a new room named "Room <n>", with the layout their
    /// arrangement matches (Focus, Columns, Grid, Stack, else Auto). No window moves. Returns the new room, or nil
    /// when no window is visible.
    @discardableResult
    public func saveVisibleWindowsAsNewRoom() -> Room? {
        let area = windowSystem.currentScreenVisibleArea()
        let visible = visibleWindows(in: area)
        guard !visible.isEmpty else { return nil }
        let measured = visible.map { window -> AppWindow in
            var w = window
            w.minimumSize = catalog.measureMinimumSize(of: window)
            return w
        }
        let current = visible.map { $0.frame }
        let layout = LayoutEngine.recognize(frames: current, count: current.count, in: area) ?? .auto
        let room = Room(name: nextDefaultRoomName(), windows: measured, layout: layout)
        rooms.append(room)
        currentRoomID = room.id
        persist()
        return room
    }

    // MARK: Keys, rename, delete

    /// ⌘1–9: gives the room that direct key, taking it from any other room; the room's own key clears it.
    public func assignDirectKey(_ key: Int, toRoom id: UUID) {
        guard (1...9).contains(key), let room = room(id) else { return }
        if room.directKey == key {
            update(id) { $0.directKey = nil }
        } else {
            for other in rooms where other.directKey == key {
                update(other.id) { $0.directKey = nil }
            }
            update(id) { $0.directKey = key }
        }
        persist()
    }

    public func beginRename(ofRoom id: UUID) {
        guard let room = room(id) else { return }
        renameDialog = RenameDialogModel(room: room, controller: self)
    }

    func dismissRenameDialog() {
        renameDialog = nil
    }

    public func rename(room id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !RoomMatcher.hasRoom(named: trimmed, in: rooms, excluding: id) else { return }
        update(id) { $0.name = trimmed }
        persist()
    }

    /// Removes the room. Never touches its windows.
    public func deleteRoom(id: UUID) {
        rooms.removeAll { $0.id == id }
        if currentRoomID == id { currentRoomID = nil }
        persist()
    }

    // MARK: Other surfaces

    public func openGettingStarted() {
        gettingStarted.present(on: windowSystem.currentScreenVisibleArea())
    }

    public func quit() {
        quitRequested = true
        onQuit()
    }
}
