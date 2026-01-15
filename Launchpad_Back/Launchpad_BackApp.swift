//
//  Launchpad_BackApp.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI
import AppKit

@main
struct Launchpad_BackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalHotKeyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("Application did finish launching")
        registerGlobalHotKey()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("Application will terminate")
        unregisterGlobalHotKey()
    }
    
    /// 註冊全局快捷鍵 (Command + L)
    private func registerGlobalHotKey() {
        // 使用 NSEvent 本地監控器（純 Swift 解決方案）
        globalHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 檢查 Command + L
            if event.modifierFlags.contains(.command) && event.keyCode == 37 {
                self?.toggleWindowVisibility()
                return nil // 消費事件，防止傳播
            }
            return event
        }
        
        Logger.info("Global hot key monitor registered successfully")
    }
    
    /// 取消註冊全局快捷鍵
    private func unregisterGlobalHotKey() {
        if let monitor = globalHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotKeyMonitor = nil
        }
        Logger.info("Global hot key monitor unregistered")
    }
    
    /// 切換視窗可見性
    private func toggleWindowVisibility() {
        guard let window = NSApplication.shared.windows.first else {
            Logger.warning("No main window found")
            return
        }
        
        if window.isVisible {
            window.orderOut(nil)
            Logger.info("Window hidden")
        } else {
            window.orderFront(nil)
            window.makeKey()
            NSApplication.shared.activate(ignoringOtherApps: true)
            Logger.info("Window shown")
        }
    }
    
    deinit {
        Logger.debug("AppDelegate deinitialized")
    }
}
