//
//  KeyboardEventManager.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 鍵盤事件管理器
/// 負責監聽和處理全局鍵盤事件
class KeyboardEventManager {
    private var keyMonitor: Any?
    
    // MARK: - 回調函數
    private let onLeftArrow: () -> Void
    private let onRightArrow: () -> Void
    private let onEscape: () -> Void
    private let onCommandW: () -> Void
    private let onCommandQ: () -> Void
    
    /// 初始化鍵盤事件管理器
    /// - Parameters:
    ///   - onLeftArrow: 左箭頭按下時的回調（也用於上箭頭）
    ///   - onRightArrow: 右箭頭按下時的回調（也用於下箭頭）
    ///   - onEscape: Escape 按下時的回調
    ///   - onCommandW: Command+W 按下時的回調
    ///   - onCommandQ: Command+Q 按下時的回調
    init(
        onLeftArrow: @escaping () -> Void,
        onRightArrow: @escaping () -> Void,
        onEscape: @escaping () -> Void,
        onCommandW: @escaping () -> Void,
        onCommandQ: @escaping () -> Void
    ) {
        self.onLeftArrow = onLeftArrow
        self.onRightArrow = onRightArrow
        self.onEscape = onEscape
        self.onCommandW = onCommandW
        self.onCommandQ = onCommandQ
    }
    
    /// 開始監聽鍵盤事件
    func startListening() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
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
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Command + W 隱藏視窗
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            onCommandW()
            return
        }
        
        // Command + Q 結束應用
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            onCommandQ()
            return
        }
        
        // Escape 鍵 (keyCode: 53)
        if event.keyCode == 53 {
            onEscape()
            return
        }
        
        // 左箭頭鍵 (keyCode: 123) - 上一頁
        if event.keyCode == 123 {
            onLeftArrow()
            return
        }
        
        // 右箭頭鍵 (keyCode: 124) - 下一頁
        if event.keyCode == 124 {
            onRightArrow()
            return
        }
        
        // 上箭頭鍵 (keyCode: 126) - 上一頁（備用操作）
        if event.keyCode == 126 {
            onLeftArrow()
            return
        }
        
        // 下箭頭鍵 (keyCode: 125) - 下一頁（備用操作）
        if event.keyCode == 125 {
            onRightArrow()
            return
        }
    }
    
    deinit {
        stopListening()
    }
}
