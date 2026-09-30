import AppKit
import Combine
import SwiftUI

/// Presents the rename dialog, the Accessibility permission dialog, and notifications from controller state.
final class DialogPresenter: NSObject, NSWindowDelegate {
    private unowned let controller: AppController
    private var cancellables: Set<AnyCancellable> = []
    private var renameWindow: NSWindow?
    private var notificationPanel: NSPanel?
    private var notificationTimer: Timer?

    init(controller: AppController) {
        self.controller = controller
        super.init()
        controller.$renameDialog
            .receive(on: RunLoop.main)
            .sink { [weak self] dialog in
                if let dialog { self?.showRename(dialog) } else { self?.hideRename() }
            }
            .store(in: &cancellables)
        controller.$permissionDialog
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] dialog in self?.showPermissionDialog(dialog) }
            .store(in: &cancellables)
        controller.$notificationMessage
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] message in self?.showNotification(message) }
            .store(in: &cancellables)
    }

    // MARK: Rename

    private func showRename(_ dialog: RenameDialogModel) {
        hideRename()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = dialog.title
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.contentView = NSHostingView(rootView: RenameDialogView(model: dialog))
        let area = controller.windowSystem.currentScreenVisibleArea()
        window.setFrameOrigin(NSPoint(x: area.midX - 210, y: area.midY - 80))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        renameWindow = window
    }

    private func hideRename() {
        renameWindow?.orderOut(nil)
        renameWindow = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === renameWindow { controller.renameDialog?.cancel() }
        return false
    }

    // MARK: Permission

    private func showPermissionDialog(_ dialog: PermissionDialogModel) {
        let alert = NSAlert()
        alert.messageText = dialog.message
        alert.informativeText = "Rooms uses the Accessibility permission to list, move, and hide windows. Enable Rooms in System Settings › Privacy & Security › Accessibility."
        alert.addButton(withTitle: dialog.openSettingsButtonTitle)
        alert.addButton(withTitle: dialog.cancelButtonTitle)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            controller.permissionDialogOpenSettings()
        } else {
            controller.permissionDialogCancel()
        }
    }

    // MARK: Notification

    private func showNotification(_ message: String) {
        notificationTimer?.invalidate()
        notificationPanel?.orderOut(nil)
        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.sizeToFit()
        let padding: CGFloat = 18
        let size = NSSize(width: label.frame.width + 2 * padding, height: label.frame.height + 2 * padding)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        label.frame.origin = NSPoint(x: padding, y: padding)
        container.addSubview(label)
        panel.contentView = container
        let area = controller.windowSystem.currentScreenVisibleArea()
        panel.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.maxY - size.height - 24))
        panel.orderFrontRegardless()
        notificationPanel = panel
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.notificationPanel?.orderOut(nil)
            self?.notificationPanel = nil
        }
    }
}

struct RenameDialogView: View {
    @ObservedObject var model: RenameDialogModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.title).font(.system(size: 15, weight: .semibold))
            TextField("Room name", text: $model.text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.confirm() }
                .onExitCommand { model.cancel() }
            Text(model.errorMessage ?? " ").font(.system(size: 12)).foregroundStyle(.red)
            HStack {
                Spacer()
                Button(model.cancelButtonTitle) { model.cancel() }.keyboardShortcut(.cancelAction)
                Button(model.renameButtonTitle) { model.confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.isRenameEnabled)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
