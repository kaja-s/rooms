import AppKit
import RoomsCore
import SwiftUI

/// Full-screen, click-through window that draws the layout preview cards behind the palette.
final class LayoutPreviewOverlayController {
    private let window: NSWindow
    private unowned let palette: PaletteViewModel

    init(palette: PaletteViewModel) {
        self.palette = palette
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.contentView = NSHostingView(rootView: LayoutPreviewOverlayView(palette: palette))
    }

    /// Covers the visible area of the palette's screen, directly below the palette and above every other window.
    func show(below panel: NSWindow) {
        window.setFrame(palette.screenArea, display: false)
        window.order(.below, relativeTo: panel.windowNumber)
    }

    func hide() {
        window.orderOut(nil)
    }
}

struct LayoutPreviewOverlayView: View {
    @ObservedObject var palette: PaletteViewModel

    var body: some View {
        let preview = palette.preview
        ZStack(alignment: .topLeading) {
            Color.clear
            if let preview {
                ForEach(preview.cards) { card in
                    GhostCardView(card: card)
                        .frame(width: card.frame.width, height: card.frame.height)
                        .offset(x: card.frame.minX - preview.area.minX,
                                y: preview.area.maxY - card.frame.maxY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: LayoutPreview.animationDuration), value: preview?.frames)
        .environment(\.colorScheme, .light)
    }
}

/// One ghost window: title bar with three dots, application name, and window title; the application icon centered.
struct GhostCardView: View {
    let card: LayoutPreviewCard

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LayoutPreviewDesign.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .top) {
            shape.fill(Color(hex: LayoutPreviewDesign.cardFillHex, opacity: LayoutPreviewDesign.cardFillOpacity))
            titleBar
            icon.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color(hex: LayoutPreviewDesign.cardBorderHex), lineWidth: LayoutPreviewDesign.cardBorderWidth))
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: LayoutPreviewDesign.dotSize) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: LayoutPreviewDesign.dotColorHex))
                        .frame(width: LayoutPreviewDesign.dotSize, height: LayoutPreviewDesign.dotSize)
                }
            }
            .padding(.leading, 12)
            Text(card.applicationName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: PaletteDesign.textPrimaryHex))
                .padding(.leading, 10)
            if !card.title.isEmpty {
                Text("— \(card.title)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: PaletteDesign.textSecondaryHex))
                    .padding(.leading, 6)
            }
            Spacer(minLength: 8)
        }
        .lineLimit(1)
        .frame(height: LayoutPreviewDesign.titleBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: PaletteDesign.dividerHex)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let image = card.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: LayoutPreviewDesign.appIconSize, height: LayoutPreviewDesign.appIconSize)
        }
    }
}
