import AppKit
import Combine
import RoomsCore
import SwiftUI

/// Window hosting the window picker; presented and dismissed by `WindowPickerViewModel.isPresented`.
final class WindowPickerWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private unowned let controller: AppController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: AppController) {
        self.controller = controller
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
                          styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "Rooms"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.contentView = NSHostingView(rootView: WindowPickerView(picker: controller.picker))

        controller.picker.$isPresented
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] presented in presented ? self?.show() : self?.hide() }
            .store(in: &cancellables)
    }

    private func show() {
        let area = controller.picker.screenArea
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
        window.title = controller.picker.title
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        window.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        controller.picker.cancel()
        return false
    }
}

struct WindowPickerView: View {
    @ObservedObject var picker: WindowPickerViewModel
    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(picker.title).font(.system(size: 20, weight: .semibold)).padding(.top, 8)
            Text("Click the windows that belong in it. The number on a card is its place in the layout; 1 is the main window.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(picker.cards.enumerated()), id: \.element.id) { index, card in
                        WindowCardView(card: card, showsIconInsteadOfSnapshot: picker.showsAppIconInsteadOfSnapshot)
                            .onTapGesture { picker.toggleCard(at: index) }
                    }
                }
                .padding(.vertical, 8)
            }
            HStack {
                Spacer()
                Button(picker.cancelButtonTitle) { picker.cancel() }.keyboardShortcut(.cancelAction)
                Button(picker.primaryButtonTitle) { picker.confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!picker.isPrimaryEnabled)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 420)
    }
}

struct WindowCardView: View {
    let card: WindowPickerViewModel.Card
    let showsIconInsteadOfSnapshot: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                    if !showsIconInsteadOfSnapshot, let snapshot = card.snapshot {
                        Image(nsImage: snapshot).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let icon = card.icon {
                        Image(nsImage: icon).resizable().frame(width: 56, height: 56)
                    }
                }
                .frame(height: 120)
                .overlay(alignment: .bottomTrailing) {
                    if let icon = card.icon, !showsIconInsteadOfSnapshot || card.snapshot != nil {
                        Image(nsImage: icon).resizable().frame(width: 24, height: 24).padding(6)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(card.isSelected ? Color.accentColor : Color.clear, lineWidth: 3))
                if let badge = card.badge {
                    Text("\(badge)")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.accentColor))
                        .padding(6)
                }
            }
            Text(card.title).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
        }
        .contentShape(Rectangle())
    }
}
