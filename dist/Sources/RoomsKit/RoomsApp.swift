import AppKit
import Foundation

/// Entry point used by the `Rooms` executable's `main.swift`.
public enum RoomsApp {
    /// The palette, window picker, Getting Started, and dialogs use the light appearance regardless of the system appearance.
    public static let appearanceName: NSAppearance.Name = .aqua
    public static var appearance: NSAppearance? { NSAppearance(named: appearanceName) }

    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.appearance = RoomsApp.appearance
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController!
    private var statusItem: StatusItemController!
    private var palettePanel: PalettePanelController!
    private var pickerWindow: WindowPickerWindowController!
    private var gettingStartedWindow: GettingStartedWindowController!
    private var dialogs: DialogPresenter!
    private var hotkeys: HotkeyCenter!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = AppController(windowSystem: AccessibilityWindowSystem())
        controller.onQuit = { NSApp.terminate(nil) }
        statusItem = StatusItemController(controller: controller)
        palettePanel = PalettePanelController(controller: controller)
        pickerWindow = WindowPickerWindowController(controller: controller)
        gettingStartedWindow = GettingStartedWindowController(controller: controller)
        dialogs = DialogPresenter(controller: controller)
        hotkeys = HotkeyCenter { [weak self] key in
            guard let controller = self?.controller else { return }
            switch key {
            case .togglePalette: controller.toggleHotkeyPressed()
            case .direct(let n): controller.directKeyPressed(n)
            case .snapLeft: controller.snapKeyPressed(.left)
            case .snapRight: controller.snapKeyPressed(.right)
            case .snapUp: controller.snapKeyPressed(.up)
            case .snapDown: controller.snapKeyPressed(.down)
            case .snapFill: controller.snapKeyPressed(.fill)
            }
        }
        hotkeys.register()
        controller.start()
    }
}
