//
//  Launchpad_BackApp.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI
import AppKit
import Carbon

@main
struct Launchpad_BackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let defaultWindowSize = NSSize(width: 1000, height: 700)
    private var globalHotKeyRef: EventHotKeyRef?
    private var globalHotKeyHandlerRef: EventHandlerRef?
    private let globalHotKeySignature: OSType = 0x4C50424B // "LPBK"
    private let globalHotKeyID: UInt32 = 1
    
    private var mainWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("Application did finish launching")
        createMainWindowIfNeeded()
        registerGlobalHotKey()
        showMainWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("Application will terminate")
        unregisterGlobalHotKey()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === mainWindow else {
            return
        }

        mainWindow = nil
        Logger.info("Main window closed")
    }
    
    func hideMainWindow() {
        guard let window = mainWindow else {
            Logger.warning("No main window found")
            return
        }
        
        window.orderOut(nil)
        logWindowState(window, context: "hide")
        Logger.info("Window hidden")
    }

    func closeMainWindow() {
        guard let window = mainWindow else {
            Logger.warning("No main window found")
            NSApp.terminate(nil)
            return
        }

        window.performClose(nil)
    }
    
    func showMainWindow() {
        createMainWindowIfNeeded()
        
        guard let window = mainWindow else {
            Logger.warning("No main window found")
            return
        }
        
        configureMainWindow(window)
        ensureWindowIsOnScreen(window)
        
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        
        logWindowState(window, context: "show")
        Logger.info("Window shown")
    }
    
    func toggleMainWindowVisibility() {
        guard let window = mainWindow else {
            showMainWindow()
            return
        }
        
        logWindowState(window, context: "toggle")
        
        if shouldHideWindow(window) {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }
    
    private func createMainWindowIfNeeded() {
        guard mainWindow == nil else { return }
        
        let rootView = ContentView()
            .preferredColorScheme(.dark)
        
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.setContentSize(defaultWindowSize)
        window.setFrame(NSRect(origin: .zero, size: defaultWindowSize), display: false)
        window.minSize = NSSize(width: 800, height: 560)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isRestorable = false
        window.delegate = self
        window.center()
        
        self.mainWindow = window
        
        configureMainWindow(window)
        Logger.info("Main window created")
    }
    
    /// 註冊全局快捷鍵 (Command + L)
    private func registerGlobalHotKey() {
        unregisterGlobalHotKey()
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                return appDelegate.handleGlobalHotKeyEvent(event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &globalHotKeyHandlerRef
        )
        
        guard handlerStatus == noErr else {
            Logger.error("Failed to install global hot key handler: \(handlerStatus)")
            return
        }
        
        let hotKeyID = EventHotKeyID(signature: globalHotKeySignature, id: globalHotKeyID)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &globalHotKeyRef
        )
        
        guard registerStatus == noErr else {
            if let handler = globalHotKeyHandlerRef {
                RemoveEventHandler(handler)
                globalHotKeyHandlerRef = nil
            }
            Logger.error("Failed to register global hot key: \(registerStatus)")
            return
        }
        
        Logger.info("Global hot key registered successfully")
    }
    
    /// 取消註冊全局快捷鍵
    private func unregisterGlobalHotKey() {
        if let hotKeyRef = globalHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            globalHotKeyRef = nil
        }
        
        if let handlerRef = globalHotKeyHandlerRef {
            RemoveEventHandler(handlerRef)
            globalHotKeyHandlerRef = nil
        }
        
        Logger.info("Global hot key unregistered")
    }
    
    private func handleGlobalHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event else { return OSStatus(eventNotHandledErr) }
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard status == noErr else {
            Logger.error("Failed to read global hot key event: \(status)")
            return status
        }
        
        guard hotKeyID.signature == globalHotKeySignature, hotKeyID.id == globalHotKeyID else {
            return OSStatus(eventNotHandledErr)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.toggleMainWindowVisibility()
        }
        
        return noErr
    }
    
    private func configureMainWindow(_ window: NSWindow) {
        var behavior = window.collectionBehavior
        behavior.insert(.moveToActiveSpace)
        behavior.insert(.fullScreenAuxiliary)
        window.collectionBehavior = behavior
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        if window.frame.width < 800 || window.frame.height < 560 {
            window.setContentSize(defaultWindowSize)
            window.setFrame(NSRect(origin: window.frame.origin, size: defaultWindowSize), display: false)
            Logger.info("Corrected zero-sized window frame")
        }
    }
    
    private func ensureWindowIsOnScreen(_ window: NSWindow) {
        let availableFrames = NSScreen.screens.map(\.visibleFrame)
        let isOnAnyScreen = availableFrames.contains { $0.intersects(window.frame) }
        
        guard !isOnAnyScreen, let targetFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
            return
        }
        
        let origin = CGPoint(
            x: targetFrame.midX - (window.frame.width / 2),
            y: targetFrame.midY - (window.frame.height / 2)
        )
        let centeredFrame = NSRect(origin: origin, size: window.frame.size)
        window.setFrame(centeredFrame, display: false)
        Logger.info("Repositioned window onto active screen")
    }
    
    private func shouldHideWindow(_ window: NSWindow) -> Bool {
        let appIsForeground = NSApplication.shared.isActive && !NSApplication.shared.isHidden
        let windowIsActuallyVisible = window.isVisible && window.occlusionState.contains(.visible)
        return appIsForeground && windowIsActuallyVisible
    }
    
    private func logWindowState(_ window: NSWindow, context: String) {
        let screenFrame = window.screen?.frame.debugDescription ?? "nil"
        let occlusion = window.occlusionState.rawValue
        Logger.info(
            "Window state [\(context)] visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow) mini=\(window.isMiniaturized) frame=\(window.frame.debugDescription) screen=\(screenFrame) level=\(window.level.rawValue) occlusion=\(occlusion)"
        )
    }
    
    deinit {
        Logger.debug("AppDelegate deinitialized")
    }
}
