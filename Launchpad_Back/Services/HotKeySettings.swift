//
//  HotKeySettings.swift
//  Launchpad_Back
//
//  全域快捷鍵綁定的儲存與轉換。
//

import AppKit
import Carbon
import Combine

extension Notification.Name {
    /// 快捷鍵綁定已變更，AppDelegate 應重新註冊
    static let hotKeyBindingChanged = Notification.Name("HotKeyBindingChanged")
    /// 設定視窗開始錄製快捷鍵，期間應暫時取消註冊全域快捷鍵
    static let hotKeyRecordingBegan = Notification.Name("HotKeyRecordingBegan")
    /// 設定視窗結束錄製快捷鍵
    static let hotKeyRecordingEnded = Notification.Name("HotKeyRecordingEnded")
}

/// 全域快捷鍵綁定
struct HotKeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let `default` = HotKeyBinding(
        keyCode: UInt32(kVK_ANSI_L),
        carbonModifiers: UInt32(cmdKey),
        display: "⌘L"
    )
}

/// 快捷鍵設定存取（UserDefaults 持久化）
final class HotKeySettingsStore: ObservableObject {
    static let shared = HotKeySettingsStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "globalToggleHotKey"

    @Published var binding: HotKeyBinding {
        didSet {
            guard binding != oldValue else { return }
            save()
            NotificationCenter.default.post(name: .hotKeyBindingChanged, object: nil)
            Logger.info("Hot key binding changed to \(binding.display)")
        }
    }

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(HotKeyBinding.self, from: data) {
            binding = decoded
        } else {
            binding = .default
        }
    }

    func resetToDefault() {
        binding = .default
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(binding) else {
            Logger.error("Failed to encode hot key binding")
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - NSEvent 轉換

    /// 從按鍵事件建立綁定
    /// 一般按鍵必須搭配 ⌘/⌥/⌃ 修飾鍵；F1–F20 功能鍵可以單獨使用
    static func makeBinding(from event: NSEvent) -> HotKeyBinding? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let isFunctionKey = functionKeyNames[event.keyCode] != nil
        let hasNonShiftModifier = (modifiers & ~UInt32(shiftKey)) != 0

        guard hasNonShiftModifier || isFunctionKey else { return nil }
        guard let keyName = keyDisplayName(for: event) else { return nil }

        return HotKeyBinding(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers,
            display: modifierSymbols(for: modifiers) + keyName
        )
    }

    /// NSEvent 修飾鍵轉 Carbon 修飾鍵
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    // MARK: - 顯示字串

    private static let functionKeyNames: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
        97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]

    private static let specialKeyNames: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟"
    ]

    private static func keyDisplayName(for event: NSEvent) -> String? {
        if let name = functionKeyNames[event.keyCode] {
            return name
        }
        if let name = specialKeyNames[event.keyCode] {
            return name
        }
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }
        return characters.uppercased()
    }

    private static func modifierSymbols(for carbonModifiers: UInt32) -> String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }
}
