//
//  KeyboardEventManager.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 鍵盤事件管理器
/// 負責監聽和處理全局鍵盤事件
/// 回傳 `true` 的回調表示事件已被消費，不再往下傳遞（例如避免方向鍵同時移動搜尋欄游標）
class KeyboardEventManager {
    private var keyMonitor: Any?

    // MARK: - 回調函數
    private let onLeftArrow: () -> Bool
    private let onRightArrow: () -> Bool
    private let onEscape: () -> Void
    private let onCommandW: () -> Void
    private let onCommandQ: () -> Void
    private let onReturn: () -> Bool
    private let onPrintableKey: (String) -> Bool

    /// 初始化鍵盤事件管理器
    /// - Parameters:
    ///   - onLeftArrow: 左箭頭按下時的回調（也用於上箭頭），回傳是否消費事件
    ///   - onRightArrow: 右箭頭按下時的回調（也用於下箭頭），回傳是否消費事件
    ///   - onEscape: Escape 按下時的回調
    ///   - onCommandW: Command+W 按下時的回調
    ///   - onCommandQ: Command+Q 按下時的回調
    ///   - onReturn: Return 按下時的回調，回傳是否消費事件
    ///   - onPrintableKey: 一般可見字元按下時的回調（用於「打字即搜尋」），回傳是否消費事件
    init(
        onLeftArrow: @escaping () -> Bool,
        onRightArrow: @escaping () -> Bool,
        onEscape: @escaping () -> Void,
        onCommandW: @escaping () -> Void,
        onCommandQ: @escaping () -> Void,
        onReturn: @escaping () -> Bool = { false },
        onPrintableKey: @escaping (String) -> Bool = { _ in false }
    ) {
        self.onLeftArrow = onLeftArrow
        self.onRightArrow = onRightArrow
        self.onEscape = onEscape
        self.onCommandW = onCommandW
        self.onCommandQ = onCommandQ
        self.onReturn = onReturn
        self.onPrintableKey = onPrintableKey
    }

    /// 開始監聽鍵盤事件
    func startListening() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event)
        }
        Logger.debug("KeyboardEventManager started listening")
    }

    /// 停止監聽鍵盤事件
    func stopListening() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        Logger.debug("KeyboardEventManager stopped listening")
    }

    /// 處理鍵盤事件；回傳 nil 表示事件已被消費
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // 只處理發往主 Launchpad 視窗的事件（避免干擾設定視窗等其他視窗）
        if let window = event.window, !(window is LaunchpadWindow) {
            return event
        }

        // Command + W 隱藏視窗
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            onCommandW()
            return nil
        }

        // Command + Q 結束應用
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            onCommandQ()
            return nil
        }

        // 其他 Command 組合鍵（如 Cmd+A 全選）交還給系統
        if event.modifierFlags.contains(.command) {
            return event
        }

        // Escape 鍵 (keyCode: 53)
        if event.keyCode == 53 {
            onEscape()
            return nil
        }

        // Return (keyCode: 36) / Enter (keyCode: 76)
        if event.keyCode == 36 || event.keyCode == 76 {
            return onReturn() ? nil : event
        }

        // 左箭頭 (123) / 上箭頭 (126) - 上一頁
        if event.keyCode == 123 || event.keyCode == 126 {
            return onLeftArrow() ? nil : event
        }

        // 右箭頭 (124) / 下箭頭 (125) - 下一頁
        if event.keyCode == 124 || event.keyCode == 125 {
            return onRightArrow() ? nil : event
        }

        // 一般可見字元（打字即搜尋）
        if let characters = event.characters,
           !characters.isEmpty,
           !event.modifierFlags.contains(.control),
           isPrintable(characters) {
            return onPrintableKey(characters) ? nil : event
        }

        return event
    }

    /// 判斷輸入是否為可見字元（排除控制字元與功能鍵）
    private func isPrintable(_ characters: String) -> Bool {
        guard let scalar = characters.unicodeScalars.first else { return false }

        // 排除控制字元（含 Tab、Delete）與私有區功能鍵（F1-F20、方向鍵等）
        if CharacterSet.controlCharacters.contains(scalar) { return false }
        if scalar.value >= 0xF700 && scalar.value <= 0xF8FF { return false }

        return true
    }

    deinit {
        stopListening()
    }
}
