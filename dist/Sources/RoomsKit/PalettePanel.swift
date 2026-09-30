import AppKit
import Combine
import RoomsCore
import SwiftUI

/// Non-activating floating panel that hosts the palette and routes its keys to `PaletteViewModel`.
final class PalettePanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let keyHandler, keyHandler(event) { return }
        super.sendEvent(event)
    }
}

final class PalettePanelController {
    private let panel: PalettePanel
    private unowned let controller: AppController
    private var cancellables: Set<AnyCancellable> = []
    private var mouseMonitor: Any?
    static let width: CGFloat = 640

    init(controller: AppController) {
        self.controller = controller
        panel = PalettePanel(contentRect: NSRect(x: 0, y: 0, width: PalettePanelController.width, height: 420),
                             styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                             backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let hosting = NSHostingView(rootView: PaletteView(palette: controller.palette, controller: controller))
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentView = hosting
        panel.keyHandler = { [weak self] event in self?.handle(event) ?? false }

        controller.palette.$isVisible
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in visible ? self?.show() : self?.hide() }
            .store(in: &cancellables)
    }

    private func show() {
        let area = controller.palette.screenArea
        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? panel.frame.size
        let width = PalettePanelController.width
        let height = max(size.height, 160)
        let origin = NSPoint(x: area.midX - width / 2, y: area.minY + area.height * 0.58 - height / 2)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        panel.makeKeyAndOrderFront(nil)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.controller.palette.clickedOutside()
        }
    }

    private func hide() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        panel.orderOut(nil)
    }

    /// Returns true when the key was handled by the palette.
    private func handle(_ event: NSEvent) -> Bool {
        let palette = controller.palette
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        switch event.keyCode {
        case 53: palette.pressEscape(); return true            // Esc
        case 126: palette.moveSelection(by: -1); return true    // ↑
        case 125: palette.moveSelection(by: 1); return true     // ↓
        case 48: palette.pressTab(shift: flags.contains(.shift)); return true // ⇥
        case 36, 76: palette.pressReturn(); return true         // ↵
        case 51 where command: palette.pressCommandDelete(); return true // ⌘⌫
        case 1 where command: palette.pressCommandS(); return true       // ⌘S
        default: break
        }
        if command, let characters = event.charactersIgnoringModifiers, let digit = Int(characters), (1...9).contains(digit) {
            palette.pressCommandDigit(digit)
            return true
        }
        return false
    }
}

// MARK: - SwiftUI

struct PaletteView: View {
    @ObservedObject var palette: PaletteViewModel
    @ObservedObject var controller: AppController
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "door.left.hand.open").font(.system(size: 20)).foregroundStyle(.secondary)
                TextField("Go to a room", text: $palette.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .regular))
                    .focused($fieldFocused)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            Divider().padding(.horizontal, 14)
            list
            if let preview = palette.preview {
                LayoutPreviewView(preview: preview).padding(.horizontal, 18).padding(.vertical, 8)
            }
            footer
        }
        .frame(width: PalettePanelController.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary))
        .onAppear { fieldFocused = true }
        .onReceive(palette.$isVisible) { visible in if visible { DispatchQueue.main.async { fieldFocused = true } } }
    }

    private var list: some View {
        let rows = palette.rows
        return VStack(spacing: 2) {
            if let empty = palette.emptyStateText {
                Text(empty).foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    PaletteRowView(row: row, isSelected: index == palette.selectedIndex,
                                   showsReturnAndDelete: palette.rowShowsReturnAndDelete(at: index),
                                   onTap: { palette.clickRow(index) },
                                   onDelete: { palette.clickDeleteButton(index) })
                        .contextMenu {
                            ForEach(palette.contextMenuItems(forRow: index), id: \.title) { item in
                                Button(item.title) { palette.performContextMenu(item.action, onRow: index) }
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            ForEach(palette.leadingFooterHints, id: \.self) { hint in
                FooterHintView(hint: hint)
            }
            .foregroundStyle(.secondary)
            Spacer()
            ForEach(palette.trailingFooterHints, id: \.self) { hint in
                FooterHintView(hint: hint)
            }
            .foregroundStyle(.tertiary)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 18).padding(.bottom, 12).padding(.top, 4)
    }
}

struct PaletteRowView: View {
    let row: PaletteRow
    let isSelected: Bool
    let showsReturnAndDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            switch row {
            case .room(let room):
                HStack(spacing: -6) {
                    ForEach(Array(room.icons.prefix(4).enumerated()), id: \.offset) { _, icon in
                        if let icon {
                            Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                        } else {
                            RoundedRectangle(cornerRadius: 5).fill(.quaternary).frame(width: 22, height: 22)
                        }
                    }
                }
                .frame(width: 96, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).font(.system(size: 15, weight: .medium))
                    Text(room.subtitle).font(.system(size: 12)).foregroundStyle(isSelected ? .primary : .secondary)
                }
                Spacer()
                if let trailer = room.trailer {
                    Text(trailer).font(.system(size: 12)).foregroundStyle(isSelected ? .primary : .secondary)
                }
                if showsReturnAndDelete {
                    Text("↵").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .help("Delete room")
                }
            case .create(let name):
                Image(systemName: "plus.circle").frame(width: 96, alignment: .leading).foregroundStyle(.secondary)
                Text("Create “\(name)”").font(.system(size: 15, weight: .medium))
                Spacer()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct LayoutPreviewView: View {
    let preview: LayoutPreview
    private let height: CGFloat = 96

    var body: some View {
        let area = preview.area
        let scale = area.width > 0 ? height / area.height : 0
        let width = area.width * scale
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary).frame(width: width, height: height)
            ForEach(Array(preview.frames.enumerated()), id: \.offset) { index, frame in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.8))
                    .overlay(Text("\(index + 1)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white))
                    .frame(width: max(2, frame.width * scale), height: max(2, frame.height * scale))
                    .offset(x: (frame.minX - area.minX) * scale, y: (area.maxY - frame.maxY) * scale)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .animation(.easeInOut(duration: LayoutPreview.animationDuration), value: preview.frames)
    }
}


/// One key hint of the footer; "⇥ Layout" shows the tab symbol as an arrow to a bar.
struct FooterHintView: View {
    let hint: String

    var body: some View {
        if hint.hasPrefix(PaletteViewModel.tabHint) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.to.line").font(.system(size: 11, weight: .medium))
                Text(hint.dropFirst(2))
            }
        } else {
            Text(hint)
        }
    }
}
