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
    private let onLeftArrow: () -> Void
    private let onRightArrow: () -> Void
    private let onEscape: () -> Void
    private let onCommandW: () -> Void
    private let onCommandQ: () -> Void
    
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
    }
    
    /// 停止監聽鍵盤事件
    func stopListening() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Command + W to hide window
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            onCommandW()
            return
        }
        
        // Command + Q to terminate app
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            onCommandQ()
            return
        }
        
        // Escape key
        if event.keyCode == 53 {
            onEscape()
            return
        }
        
        // Left arrow key
        if event.keyCode == 123 {
            onLeftArrow()
            return
        }
        
        // Right arrow key
        if event.keyCode == 124 {
            onRightArrow()
            return
        }
        
        // Up arrow key - 也可以用來翻頁
        if event.keyCode == 126 {
            onLeftArrow()
            return
        }
        
        // Down arrow key - 也可以用來翻頁
        if event.keyCode == 125 {
            onRightArrow()
            return
        }
    }
    
    deinit {
        stopListening()
    }
}
