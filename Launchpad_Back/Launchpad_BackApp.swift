//
//  Launchpad_BackApp.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI
import Carbon

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
        .defaultSize(width: 1200, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var globalHotKey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        registerGlobalHotKey()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKey()
    }
    
    private func registerGlobalHotKey() {
        // 註冊 Command + L 快捷鍵 (L for Launchpad)
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C50), id: 1) // 'LP' for Launchpad
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // 顯示或隱藏視窗
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    if window.isVisible {
                        window.orderOut(nil)
                    } else {
                        window.orderFront(nil)
                        window.makeKey()
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
        
        // Command + L (37 是 L 的 keyCode)
        RegisterEventHotKey(37, UInt32(cmdKey), hotKeyID, GetApplicationEventTarget(), 0, &globalHotKey)
    }
    
    private func unregisterGlobalHotKey() {
        if let hotKey = globalHotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}
