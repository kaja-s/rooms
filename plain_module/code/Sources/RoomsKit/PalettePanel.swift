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
    private let hosting: NSHostingView<PaletteView>
    private unowned let controller: AppController
    private let overlay: LayoutPreviewOverlayController
    private var cancellables: Set<AnyCancellable> = []
    private var mouseMonitor: Any?
    /// Top edge of the panel while it is open; the panel grows and shrinks downwards from it.
    private var topEdge: CGFloat = 0

    init(controller: AppController) {
        self.controller = controller
        panel = PalettePanel(contentRect: NSRect(x: 0, y: 0, width: PaletteDesign.panelWidth, height: 300),
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
        hosting = NSHostingView(rootView: PaletteView(palette: controller.palette, controller: controller))
        hosting.sizingOptions = []
        panel.contentView = hosting
        overlay = LayoutPreviewOverlayController(palette: controller.palette)
        panel.keyHandler = { [weak self] event in self?.handle(event) ?? false }

        controller.palette.$isVisible
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in visible ? self?.show() : self?.hide() }
            .store(in: &cancellables)

        // Rows appear and disappear while typing; keep the panel sized to its content.
        controller.palette.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resizeToContent() }
            .store(in: &cancellables)

        controller.palette.$isPreviewVisible
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.updateOverlay(visible: visible) }
            .store(in: &cancellables)
    }

    /// The panel is exactly as tall as its content, computed from the design tokens.
    private func contentHeight() -> CGFloat {
        controller.palette.panelHeight
    }

    private func show() {
        let area = controller.palette.screenArea
        let height = contentHeight()
        let width = PaletteDesign.panelWidth
        topEdge = (area.minY + area.height * 0.62 + height / 2).rounded()
        let origin = NSPoint(x: (area.midX - width / 2).rounded(), y: topEdge - height)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.controller.palette.clickedOutside()
        }
    }

    private func resizeToContent() {
        guard controller.palette.isVisible else { return }
        // objectWillChange fires before the change lands; measure on the next turn of the run loop.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.controller.palette.isVisible else { return }
            let height = self.contentHeight()
            guard abs(height - self.panel.frame.height) >= 1 else { return }
            var frame = self.panel.frame
            frame.origin.y = self.topEdge - height
            frame.size.height = height
            self.panel.setFrame(frame, display: true)
            self.panel.invalidateShadow()
        }
    }

    private func updateOverlay(visible: Bool) {
        if visible && controller.palette.isVisible {
            overlay.show(below: panel)
        } else {
            overlay.hide()
        }
    }

    private func hide() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        overlay.hide()
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

// MARK: - Design colors

extension Color {
    /// sRGB color from "#RRGGBB".
    init(hex: String, opacity: Double = 1) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum PaletteColors {
    static let panelFill = Color(hex: PaletteDesign.panelFillHex, opacity: PaletteDesign.panelFillOpacity)
    static let panelBorder = Color.black.opacity(PaletteDesign.panelBorderOpacity)
    static let textPrimary = Color(hex: PaletteDesign.textPrimaryHex)
    static let textSecondary = Color(hex: PaletteDesign.textSecondaryHex)
    static let textTertiary = Color(hex: PaletteDesign.textTertiaryHex)
    static let divider = Color(hex: PaletteDesign.dividerHex)
    static let selection = Color(hex: PaletteDesign.selectionHex)
    static let onSelection = Color(hex: PaletteDesign.onSelectionHex)
    static let onSelectionMuted = Color(hex: PaletteDesign.onSelectionHex, opacity: PaletteDesign.onSelectionMutedOpacity)
}

// MARK: - SwiftUI

struct PaletteView: View {
    @ObservedObject var palette: PaletteViewModel
    @ObservedObject var controller: AppController
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(PaletteDesign.sections.enumerated()), id: \.offset) { _, section in
                switch section {
                case .searchField: searchField
                case .divider: divider
                case .list: list
                case .keyHints: footer
                }
            }
        }
        .frame(width: PaletteDesign.panelWidth, height: palette.panelHeight, alignment: .top)
        .background(PaletteColors.panelFill, in: RoundedRectangle(cornerRadius: PaletteDesign.panelCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PaletteDesign.panelCornerRadius, style: .continuous).strokeBorder(PaletteColors.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: PaletteDesign.panelCornerRadius, style: .continuous))
        .environment(\.colorScheme, .light)
        .onAppear { fieldFocused = true }
        .onReceive(palette.$isVisible) { visible in if visible { DispatchQueue.main.async { fieldFocused = true } } }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(PaletteColors.textSecondary)
            TextField("", text: $palette.query, prompt: Text("Go to a room"))
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(PaletteColors.textPrimary)
                .tint(PaletteColors.selection)
                .focused($fieldFocused)
        }
        .padding(.horizontal, PaletteDesign.horizontalInset)
        .frame(height: PaletteDesign.searchRowHeight)
    }

    private var divider: some View {
        Rectangle()
            .fill(PaletteColors.divider)
            .frame(height: PaletteDesign.dividerHeight)
            .padding(.horizontal, PaletteDesign.horizontalInset)
    }

    private var list: some View {
        let rows = palette.rows
        return VStack(spacing: PaletteDesign.rowSpacing) {
            if let empty = palette.emptyStateText {
                Text(empty)
                    .font(.system(size: 15))
                    .foregroundStyle(PaletteColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: PaletteDesign.emptyStateHeight)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    PaletteRowView(row: row,
                                   isSelected: index == palette.selectedIndex,
                                   trailingElements: palette.rowTrailingElements(at: index),
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
        .padding(.horizontal, PaletteDesign.listInset)
        .padding(.top, PaletteDesign.dividerToList + PaletteDesign.listInset)
        .padding(.bottom, PaletteDesign.listInset)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            ForEach(palette.leadingFooterHints, id: \.self) { hint in
                FooterHintView(hint: hint)
            }
            .foregroundStyle(PaletteColors.textSecondary)
            Spacer(minLength: 16)
            ForEach(palette.trailingFooterHints, id: \.self) { hint in
                FooterHintView(hint: hint)
            }
            .foregroundStyle(PaletteColors.textTertiary)
        }
        .font(.system(size: 14))
        .lineLimit(1)
        .padding(.horizontal, PaletteDesign.horizontalInset)
        .frame(height: PaletteDesign.footerHeight)
    }
}

struct PaletteRowView: View {
    let row: PaletteRow
    let isSelected: Bool
    /// Trailer, then "↵" and "ⓧ" for the selected room row.
    let trailingElements: [String]
    let onTap: () -> Void
    let onDelete: () -> Void

    private var nameColor: Color { isSelected ? PaletteColors.onSelection : PaletteColors.textPrimary }
    private var secondaryColor: Color { isSelected ? PaletteColors.onSelectionMuted : PaletteColors.textSecondary }

    var body: some View {
        HStack(spacing: 0) {
            switch row {
            case .room(let room):
                IconClusterView(icons: room.icons)
                    .frame(width: PaletteDesign.iconSlotWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(nameColor)
                    Text(room.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryColor)
                }
                .lineLimit(1)
                Spacer(minLength: 12)
                trailing
            case .create(let name):
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? PaletteColors.onSelectionMuted : PaletteColors.textSecondary)
                    .frame(width: PaletteDesign.iconSlotWidth, alignment: .leading)
                Text("Create “\(name)”")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                Spacer(minLength: 12)
                if isSelected {
                    Text(PaletteDesign.returnGlyph)
                        .font(.system(size: 14))
                        .foregroundStyle(PaletteColors.onSelection)
                }
            }
        }
        .padding(.horizontal, PaletteDesign.rowHorizontalPadding)
        .frame(height: PaletteDesign.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: PaletteDesign.rowCornerRadius, style: .continuous)
                    .fill(PaletteColors.selection)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var trailing: some View {
        HStack(spacing: 14) {
            ForEach(Array(trailingElements.enumerated()), id: \.offset) { _, element in
                switch element {
                case PaletteDesign.returnGlyph:
                    Text(element)
                        .font(.system(size: 14))
                        .foregroundStyle(PaletteColors.onSelection)
                case PaletteDesign.deleteGlyph:
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(PaletteColors.selection, PaletteColors.onSelection)
                    }
                    .buttonStyle(.plain)
                    .help("Delete room")
                default:
                    Text(element)
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryColor)
                }
            }
        }
    }
}

/// Up to four application icons, each overlapping the previous one.
struct IconClusterView: View {
    let icons: [NSImage?]

    var body: some View {
        HStack(spacing: -PaletteDesign.iconOverlap) {
            ForEach(Array(icons.prefix(PaletteDesign.maxIcons).enumerated()), id: \.offset) { _, icon in
                Group {
                    if let icon {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        RoundedRectangle(cornerRadius: PaletteDesign.iconCornerRadius).fill(PaletteColors.divider)
                    }
                }
                .frame(width: PaletteDesign.iconSize, height: PaletteDesign.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: PaletteDesign.iconCornerRadius, style: .continuous))
            }
        }
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
