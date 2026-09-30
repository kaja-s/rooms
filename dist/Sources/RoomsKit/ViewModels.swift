import AppKit
import Combine
import Foundation
import RoomsCore

// MARK: - Palette

/// One row of the palette list.
public struct PaletteRoomRow: Equatable {
    public var id: UUID
    public var name: String
    /// "<layout name> · <count> windows"
    public var subtitle: String
    /// One application icon per window, in window order.
    public var icons: [NSImage?]
    /// "Current" when the room is the current room, otherwise "⌃⌥<n>" when a direct key is set.
    public var trailer: String?
    public var isCurrent: Bool
    public var directKey: Int?

    public static func == (lhs: PaletteRoomRow, rhs: PaletteRoomRow) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.subtitle == rhs.subtitle && lhs.trailer == rhs.trailer
            && lhs.isCurrent == rhs.isCurrent && lhs.icons.count == rhs.icons.count && lhs.directKey == rhs.directKey
    }
}

public enum PaletteRow: Equatable {
    case room(PaletteRoomRow)
    /// "Create “<typed text>”"
    case create(name: String)

    public var title: String {
        switch self {
        case .room(let row): return row.name
        case .create(let name): return "Create “\(name)”"
        }
    }

    public var roomID: UUID? {
        if case .room(let row) = self { return row.id }
        return nil
    }
}

/// Miniature of the visible area with one rectangle per window at its computed frame.
public struct LayoutPreview: Equatable {
    public var area: CGRect
    /// Frames in window (place-number) order; the label of rectangle i is i + 1.
    public var frames: [CGRect]
    public var layout: Layout
    /// Rectangles glide to new positions over this duration when the layout changes.
    public static let animationDuration: TimeInterval = 0.2
}

public struct ContextMenuItem: Equatable {
    public enum Action: Equatable { case editWindows, rename, delete }
    public var title: String
    public var action: Action
}

public final class PaletteViewModel: ObservableObject {
    public static let returnHint = "↵ Go"
    public static let escapeHint = "esc Close"
    public static let tabHint = "⇥ Layout"
    public static let rememberHint = "⌘S Remember mine"
    public static let keyHint = "⌘1–9 Key"
    public static let emptyStateText = "No rooms yet. Type a name and press ↵ to create one."
    public static let contextMenu: [ContextMenuItem] = [
        ContextMenuItem(title: "Edit Windows…", action: .editWindows),
        ContextMenuItem(title: "Rename…", action: .rename),
        ContextMenuItem(title: "Delete", action: .delete),
    ]

    private unowned let controller: AppController

    @Published public private(set) var isVisible = false
    @Published public var query = "" {
        didSet { if query != oldValue { selectedIndex = defaultSelection() } }
    }
    @Published public var selectedIndex = 0
    /// Visible area of the screen the palette opened on.
    @Published public private(set) var screenArea: CGRect = .zero

    init(controller: AppController) {
        self.controller = controller
    }

    // MARK: Rows

    public var rows: [PaletteRow] {
        let ordered = RoomMatcher.defaultOrder(controller.rooms)
        let matching = RoomMatcher.filter(ordered, query: query)
        var result: [PaletteRow] = matching.map { .room(row(for: $0)) }
        if !query.isEmpty && !RoomMatcher.hasRoom(named: query, in: controller.rooms) {
            result.append(.create(name: query))
        }
        return result
    }

    private func row(for room: Room) -> PaletteRoomRow {
        let isCurrent = controller.currentRoomID == room.id
        let trailer: String?
        if isCurrent {
            trailer = "Current"
        } else if let key = room.directKey {
            trailer = "⌃⌥\(key)"
        } else {
            trailer = nil
        }
        return PaletteRoomRow(
            id: room.id,
            name: room.name,
            subtitle: "\(room.layout.displayName) · \(room.windows.count) windows",
            icons: room.windows.map { controller.windowSystem.icon(forBundleIdentifier: $0.bundleIdentifier) },
            trailer: trailer,
            isCurrent: isCurrent,
            directKey: room.directKey
        )
    }

    /// Shown in the list area when there are no rooms and nothing is typed.
    public var emptyStateText: String? {
        controller.rooms.isEmpty && query.isEmpty ? PaletteViewModel.emptyStateText : nil
    }

    private func defaultSelection() -> Int {
        let current = rows
        guard !current.isEmpty else { return 0 }
        // The Create row is selected only when there are no matches.
        return 0
    }

    public var selectedRow: PaletteRow? {
        let current = rows
        guard current.indices.contains(selectedIndex) else { return nil }
        return current[selectedIndex]
    }

    public var selectedRoom: Room? {
        guard let id = selectedRow?.roomID else { return nil }
        return controller.room(id)
    }

    public var isCreateRowSelected: Bool {
        if case .create = selectedRow { return true }
        return false
    }

    /// The selected row shows "↵" and an ⓧ button after its trailer.
    public func rowShowsReturnAndDelete(at index: Int) -> Bool {
        guard index == selectedIndex, let row = selectedRow, case .room = row else { return false }
        return true
    }

    // MARK: Footer

    /// "Here: <resolved layout name>" for the selected room.
    public var hereText: String? {
        guard let room = selectedRoom else { return nil }
        let resolved = LayoutEngine.resolve(room.layout, windows: room.windows, myLayoutFrames: room.myLayoutFrames, in: screenArea)
        return "Here: \(resolved.displayName)"
    }

    /// Left group of the footer row: "Here: <resolved layout name>" when a room is selected, then "⇥ Layout", "⌘S Remember mine", "⌘1–9 Key".
    public var leadingFooterHints: [String] {
        var hints: [String] = []
        if let here = hereText { hints.append(here) }
        hints += [PaletteViewModel.tabHint, PaletteViewModel.rememberHint, PaletteViewModel.keyHint]
        return hints
    }

    /// Right group of the footer row, shown in a lighter color: "↵ Go", "esc Close".
    public var trailingFooterHints: [String] {
        [PaletteViewModel.returnHint, PaletteViewModel.escapeHint]
    }

    /// Every footer hint, left group then right group.
    public var footerHints: [String] {
        leadingFooterHints + trailingFooterHints
    }

    /// Layout preview for the selected room; nil when the Create row is selected or nothing is selected.
    public var preview: LayoutPreview? {
        guard let room = selectedRoom else { return nil }
        let (layout, frames) = LayoutEngine.frames(for: room.windows, layout: room.layout, myLayoutFrames: room.myLayoutFrames, in: screenArea)
        return LayoutPreview(area: screenArea, frames: frames, layout: layout)
    }

    // MARK: Visibility

    public func open() {
        screenArea = controller.windowSystem.currentScreenVisibleArea()
        query = ""
        selectedIndex = 0
        isVisible = true
    }

    public func close() {
        isVisible = false
    }

    public func toggle() {
        if isVisible { close() } else { open() }
    }

    // MARK: Keys

    public func moveSelection(by delta: Int) {
        let count = rows.count
        guard count > 0 else { selectedIndex = 0; return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    public func pressReturn() {
        guard let row = selectedRow else { return }
        switch row {
        case .room(let r):
            close()
            controller.showRoom(id: r.id)
        case .create(let name):
            close()
            controller.beginCreateRoom(named: name)
        }
    }

    public func pressEscape() { close() }

    public func clickedOutside() { close() }

    public func clickRow(_ index: Int) {
        guard rows.indices.contains(index) else { return }
        selectedIndex = index
        pressReturn()
    }

    public func pressTab(shift: Bool = false) {
        guard let room = selectedRoom else { return }
        let available = LayoutEngine.availableLayouts(windows: room.windows, myLayoutFrames: room.myLayoutFrames, in: screenArea)
        guard !available.isEmpty else { return }
        let position = available.firstIndex(of: room.layout) ?? -1
        let next: Layout
        if shift {
            next = position <= 0 ? available[available.count - 1] : available[position - 1]
        } else {
            next = available[(position + 1) % available.count]
        }
        controller.setLayout(next, ofRoom: room.id)
        objectWillChange.send()
    }

    public func pressCommandS() {
        guard let room = selectedRoom else { return }
        controller.rememberArrangement(ofRoom: room.id)
        objectWillChange.send()
    }

    public func pressCommandDigit(_ digit: Int) {
        guard (1...9).contains(digit), let room = selectedRoom else { return }
        controller.assignDirectKey(digit, toRoom: room.id)
        objectWillChange.send()
    }

    public func pressCommandDelete() {
        guard let room = selectedRoom else { return }
        deleteRoom(room.id)
    }

    public func clickDeleteButton(_ index: Int) {
        guard rows.indices.contains(index), let id = rows[index].roomID else { return }
        deleteRoom(id)
    }

    private func deleteRoom(_ id: UUID) {
        controller.deleteRoom(id: id)
        let count = rows.count
        selectedIndex = count == 0 ? 0 : min(selectedIndex, count - 1)
        objectWillChange.send()
    }

    // MARK: Context menu

    public func contextMenuItems(forRow index: Int) -> [ContextMenuItem] {
        guard rows.indices.contains(index), rows[index].roomID != nil else { return [] }
        return PaletteViewModel.contextMenu
    }

    public func performContextMenu(_ action: ContextMenuItem.Action, onRow index: Int) {
        guard rows.indices.contains(index), let id = rows[index].roomID else { return }
        switch action {
        case .editWindows:
            close()
            controller.beginEditWindows(ofRoom: id)
        case .rename:
            controller.beginRename(ofRoom: id)
        case .delete:
            deleteRoom(id)
        }
    }
}

// MARK: - Window picker

public final class WindowPickerViewModel: ObservableObject {
    public enum Mode: Equatable {
        case create(name: String)
        case edit(roomID: UUID)
    }

    public struct Card: Identifiable, Equatable {
        public var id: WindowIdentity { window.identity }
        public var window: AppWindow
        /// Window title, or the application name when the title is empty.
        public var title: String
        public var applicationName: String
        public var icon: NSImage?
        public var snapshot: NSImage?
        /// Place number when selected: 1 for the first selected card, then in selection order.
        public var badge: Int?
        public var isSelected: Bool { badge != nil }

        public static func == (lhs: Card, rhs: Card) -> Bool {
            lhs.window == rhs.window && lhs.title == rhs.title && lhs.badge == rhs.badge && lhs.applicationName == rhs.applicationName
        }
    }

    private unowned let controller: AppController

    @Published public private(set) var isPresented = false
    @Published public private(set) var mode: Mode = .create(name: "")
    @Published public private(set) var cards: [Card] = []
    @Published public private(set) var screenArea: CGRect = .zero
    /// True when snapshots are unavailable (no Screen Recording permission) and cards show the application icon instead.
    @Published public private(set) var showsAppIconInsteadOfSnapshot = false

    private var selection: [WindowIdentity] = []

    init(controller: AppController) {
        self.controller = controller
    }

    public var roomName: String {
        switch mode {
        case .create(let name): return name
        case .edit(let id): return controller.room(id)?.name ?? ""
        }
    }

    public var title: String {
        switch mode {
        case .create(let name): return "Choose the windows for “\(name)”"
        case .edit: return "Edit the windows of “\(roomName)”"
        }
    }

    public let cancelButtonTitle = "Cancel"

    public var primaryButtonTitle: String {
        switch mode {
        case .create: return "Create Room"
        case .edit: return "Save Room"
        }
    }

    public var isPrimaryEnabled: Bool { !selection.isEmpty }

    /// Selected windows in place-number order.
    public var selectedWindows: [AppWindow] {
        selection.compactMap { id in cards.first { $0.id == id }?.window }
    }

    func present(mode: Mode, windows: [AppWindow], preselected: [WindowIdentity]) {
        self.mode = mode
        screenArea = controller.windowSystem.currentScreenVisibleArea()
        showsAppIconInsteadOfSnapshot = !controller.windowSystem.hasScreenRecordingPermission
        selection = preselected.filter { id in windows.contains { $0.identity == id } }
        cards = windows.map { window in
            Card(window: window,
                 title: window.title.isEmpty ? window.applicationName : window.title,
                 applicationName: window.applicationName,
                 icon: controller.windowSystem.icon(forBundleIdentifier: window.bundleIdentifier),
                 snapshot: controller.windowSystem.hasScreenRecordingPermission ? controller.windowSystem.snapshot(of: window.identity) : nil,
                 badge: nil)
        }
        renumber()
        isPresented = true
    }

    private func renumber() {
        for i in cards.indices {
            if let position = selection.firstIndex(of: cards[i].id) {
                cards[i].badge = position + 1
            } else {
                cards[i].badge = nil
            }
        }
    }

    /// Clicking a card toggles its selection; a deselected card re-added goes to the end.
    public func toggleCard(at index: Int) {
        guard cards.indices.contains(index) else { return }
        toggleCard(cards[index].id)
    }

    public func toggleCard(_ id: WindowIdentity) {
        if let position = selection.firstIndex(of: id) {
            selection.remove(at: position)
        } else {
            selection.append(id)
        }
        renumber()
    }

    public func confirm() {
        guard isPrimaryEnabled else { return }
        let windows = selectedWindows
        let currentMode = mode
        dismiss()
        switch currentMode {
        case .create(let name):
            controller.createRoom(named: name, windows: windows)
        case .edit(let id):
            controller.replaceWindows(ofRoom: id, with: windows)
        }
    }

    public func cancel() { dismiss() }

    private func dismiss() {
        isPresented = false
        cards = []
        selection = []
    }
}

// MARK: - Status menu

public struct StatusMenuItem: Equatable {
    public enum Action: Equatable { case header, showPalette, editWindows, rename, gettingStarted, quit }
    public var title: String
    public var isEnabled: Bool
    public var action: Action
    public var keyEquivalentHint: String?
}

public final class StatusMenuModel: ObservableObject {
    private unowned let controller: AppController

    init(controller: AppController) {
        self.controller = controller
    }

    /// The name of the current room, or "No room".
    public var headerTitle: String {
        controller.currentRoom?.name ?? "No room"
    }

    public var items: [StatusMenuItem] {
        let hasCurrent = controller.currentRoom != nil
        return [
            StatusMenuItem(title: headerTitle, isEnabled: false, action: .header, keyEquivalentHint: nil),
            StatusMenuItem(title: "Show Palette", isEnabled: true, action: .showPalette, keyEquivalentHint: "⌥Space"),
            StatusMenuItem(title: "Edit Windows…", isEnabled: hasCurrent, action: .editWindows, keyEquivalentHint: nil),
            StatusMenuItem(title: "Rename…", isEnabled: hasCurrent, action: .rename, keyEquivalentHint: nil),
            StatusMenuItem(title: "Getting Started", isEnabled: true, action: .gettingStarted, keyEquivalentHint: nil),
            StatusMenuItem(title: "Quit Rooms", isEnabled: true, action: .quit, keyEquivalentHint: nil),
        ]
    }

    public func perform(_ action: StatusMenuItem.Action) {
        switch action {
        case .header: break
        case .showPalette: controller.palette.open()
        case .editWindows: if let id = controller.currentRoomID { controller.beginEditWindows(ofRoom: id) }
        case .rename: if let id = controller.currentRoomID { controller.beginRename(ofRoom: id) }
        case .gettingStarted: controller.openGettingStarted()
        case .quit: controller.quit()
        }
    }
}

// MARK: - Getting Started

public final class GettingStartedModel: ObservableObject {
    public let title = "Getting Started"
    public let steps: [String] = [
        "Open the windows a project needs.",
        "Press ⌥Space, type a name for the room, and press ↵.",
        "Click the windows that belong in it; the number on a card is its place, and 1 is the main window. Then Create Room.",
        "Press ⇥ in ⌥Space to change the layout.",
    ]
    public let footerText = "From then on, ⌥Space and the room's name, or ⌃⌥1–9, brings it back."
    public let doneButtonTitle = "Done"

    @Published public private(set) var isPresented = false
    @Published public private(set) var screenArea: CGRect = .zero

    func present(on area: CGRect) {
        screenArea = area
        isPresented = true
    }

    public func done() { isPresented = false }
}

// MARK: - Dialogs

public final class RenameDialogModel: ObservableObject {
    public static let duplicateMessage = "A room with this name already exists"
    public let roomID: UUID
    public let title: String
    public let cancelButtonTitle = "Cancel"
    public let renameButtonTitle = "Rename"
    @Published public var text: String
    private unowned let controller: AppController

    init(room: Room, controller: AppController) {
        roomID = room.id
        title = "Rename “\(room.name)”"
        text = room.name
        self.controller = controller
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var isDuplicate: Bool {
        RoomMatcher.hasRoom(named: trimmed, in: controller.rooms, excluding: roomID)
    }

    public var isRenameEnabled: Bool { !trimmed.isEmpty && !isDuplicate }

    public var errorMessage: String? { isDuplicate ? RenameDialogModel.duplicateMessage : nil }

    /// ↵ triggers Rename. Returns false when Rename is disabled.
    @discardableResult
    public func confirm() -> Bool {
        guard isRenameEnabled else { return false }
        controller.rename(room: roomID, to: trimmed)
        controller.dismissRenameDialog()
        return true
    }

    /// Esc triggers Cancel.
    public func cancel() { controller.dismissRenameDialog() }
}

public struct PermissionDialogModel: Equatable {
    public let message = "Rooms needs Accessibility access to see and move windows"
    public let openSettingsButtonTitle = "Open System Settings"
    public let cancelButtonTitle = "Cancel"
}
