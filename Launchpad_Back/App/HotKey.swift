import AppKit
import Carbon

/// A global keyboard shortcut. The stored shape matches 2.x so customized shortcuts survive the upgrade.
nonisolated struct HotKey: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let `default` = HotKey(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: UInt32(cmdKey), display: "⌘L")

    /// Regular keys need ⌘, ⌥ or ⌃; F1–F20 work alone, so F4 can act like the original Launchpad key.
    init?(event: NSEvent) {
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        let functionKey = Self.functionKeys[event.keyCode]
        guard modifiers & ~UInt32(shiftKey) != 0 || functionKey != nil else { return nil }
        guard let key = functionKey ?? Self.specialKeys[event.keyCode]
                ?? event.charactersIgnoringModifiers.flatMap({ $0.isEmpty ? nil : $0.uppercased() }) else { return nil }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers, display: Self.symbols(for: modifiers) + key)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.display = display
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    private static func symbols(for modifiers: UInt32) -> String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }
            .map(\.1)
            .joined()
    }

    private static let functionKeys: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    private static let specialKeys: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]
}

/// Registers one system-wide shortcut through Carbon, which needs no Accessibility permission.
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    var action: () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register(_ hotKey: HotKey) {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: 0x4C50_424B, id: 1) // "LPBK"
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { NSLog("Launchpad: could not register %@ (%d)", hotKey.display, status) }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
