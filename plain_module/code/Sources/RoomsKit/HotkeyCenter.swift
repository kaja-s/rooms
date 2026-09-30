import Carbon
import Foundation

/// Global hotkeys registered with the Carbon `RegisterEventHotKey` API.
public final class HotkeyCenter {
    public enum Key: Equatable {
        case togglePalette
        case direct(Int)
        case snapLeft, snapRight, snapUp, snapDown, snapFill
    }

    private let handler: (Key) -> Void
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var registry: [UInt32: Key] = [:]
    private static let signature: OSType = 0x524F_4F4D // "ROOM"

    public init(handler: @escaping (Key) -> Void) {
        self.handler = handler
    }

    public func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue().fire(hotKeyID.id)
            return noErr
        }, 1, &spec, pointer, &eventHandler)

        let controlOption = UInt32(controlKey | optionKey)
        add(.togglePalette, keyCode: 49, modifiers: UInt32(optionKey)) // Space
        let digitCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25] // 1…9
        for (index, code) in digitCodes.enumerated() {
            add(.direct(index + 1), keyCode: code, modifiers: controlOption)
        }
        add(.snapLeft, keyCode: 123, modifiers: controlOption)
        add(.snapRight, keyCode: 124, modifiers: controlOption)
        add(.snapDown, keyCode: 125, modifiers: controlOption)
        add(.snapUp, keyCode: 126, modifiers: controlOption)
        add(.snapFill, keyCode: 36, modifiers: controlOption) // Return
    }

    private func add(_ key: Key, keyCode: UInt32, modifiers: UInt32) {
        let id = UInt32(registry.count + 1)
        registry[id] = key
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotkeyCenter.signature, id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }

    private func fire(_ id: UInt32) {
        guard let key = registry[id] else { return }
        handler(key)
    }

    deinit {
        for ref in hotKeyRefs { if let ref { UnregisterEventHotKey(ref) } }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
