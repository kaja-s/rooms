import AppKit
import Combine

/// The menu bar status item and its drop-down menu, built from `StatusMenuModel`.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private unowned let controller: AppController
    private let menu = NSMenu()

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "door.left.hand.open", accessibilityDescription: "Rooms")
                ?? NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Rooms")
            button.toolTip = "Rooms"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()
        for (index, item) in controller.statusMenu.items.enumerated() {
            let menuItem = NSMenuItem(title: item.title, action: #selector(itemChosen(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            menuItem.isEnabled = item.isEnabled
            if item.action == .header {
                menuItem.isEnabled = false
                menu.addItem(menuItem)
                menu.addItem(.separator())
                continue
            }
            if item.action == .showPalette {
                menuItem.keyEquivalent = " "
                menuItem.keyEquivalentModifierMask = [.option]
            }
            if item.action == .quit {
                menu.addItem(.separator())
                menuItem.keyEquivalent = "q"
            }
            menu.addItem(menuItem)
        }
    }

    @objc private func itemChosen(_ sender: NSMenuItem) {
        let items = controller.statusMenu.items
        guard items.indices.contains(sender.tag) else { return }
        controller.statusMenu.perform(items[sender.tag].action)
    }
}
