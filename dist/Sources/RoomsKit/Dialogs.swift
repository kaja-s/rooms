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
        controller.$notification
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] notification in self?.showNotification(notification) }
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

    /// Shows a notification per NotificationDesign above every window, on every Space and over full-screen apps.
    /// A new notification replaces the one showing and restarts its duration.
    private func showNotification(_ notification: RoomsNotification) {
        notificationTimer?.invalidate()
        notificationPanel?.orderOut(nil)
        let icons = notification.applications.prefix(NotificationDesign.maxIcons).compactMap {
            controller.windowSystem.icon(forBundleIdentifier: $0.bundleIdentifier)
        }
        let hosting = NSHostingView(rootView: NotificationView(message: notification.message, icons: Array(icons)))
        let size = hosting.fittingSize
        let panel = NotificationPanel(contentRect: NSRect(origin: .zero, size: size),
                                      styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        let area = controller.windowSystem.currentScreenVisibleArea()
        panel.setFrameOrigin(NSPoint(x: (area.midX - size.width / 2).rounded(),
                                     y: (area.maxY - NotificationDesign.topInset - size.height).rounded()))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NotificationDesign.fadeInDuration
            panel.animator().alphaValue = 1
        }
        notificationPanel = panel
        notificationTimer = Timer.scheduledTimer(withTimeInterval: NotificationDesign.duration, repeats: false) { [weak self, weak panel] _ in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = NotificationDesign.fadeOutDuration
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if self?.notificationPanel === panel { self?.notificationPanel = nil }
            })
        }
    }
}

/// A notification never becomes key or main, so it never takes keyboard focus.
private final class NotificationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The notification content: the missing applications' icons (or an alert symbol), a "Rooms" caption, and the message.
struct NotificationView: View {
    let message: String
    let icons: [NSImage]

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: NotificationDesign.cornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .center, spacing: NotificationDesign.iconToText) {
            iconCluster
            VStack(alignment: .leading, spacing: 2) {
                Text(NotificationDesign.caption)
                    .font(.system(size: NotificationDesign.captionFontSize))
                    .foregroundStyle(Color(hex: NotificationDesign.textSecondaryHex))
                Text(message)
                    .font(.system(size: NotificationDesign.messageFontSize, weight: .medium))
                    .foregroundStyle(Color(hex: NotificationDesign.textPrimaryHex))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: NotificationDesign.maxWidth - 120, alignment: .leading)
        }
        .padding(.vertical, NotificationDesign.paddingVertical)
        .padding(.leading, NotificationDesign.paddingLeading)
        .padding(.trailing, NotificationDesign.paddingTrailing)
        .frame(minWidth: NotificationDesign.minWidth, alignment: .leading)
        .fixedSize()
        .background(Color(hex: NotificationDesign.fillHex, opacity: NotificationDesign.fillOpacity), in: shape)
        .overlay(shape.strokeBorder(Color.black.opacity(NotificationDesign.borderOpacity), lineWidth: 1))
        .clipShape(shape)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private var iconCluster: some View {
        if icons.isEmpty {
            Image(systemName: NotificationDesign.fallbackSymbol)
                .font(.system(size: NotificationDesign.fallbackIconSize))
                .foregroundStyle(Color(hex: NotificationDesign.accentHex))
        } else {
            HStack(spacing: -NotificationDesign.iconOverlap) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: NotificationDesign.iconSize, height: NotificationDesign.iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: NotificationDesign.iconCornerRadius, style: .continuous))
                }
            }
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
