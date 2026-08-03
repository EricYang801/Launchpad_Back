//
//  Launchpad_BackApp.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI
import AppKit
import Carbon

extension Notification.Name {
    /// 視窗即將以動畫顯示，SwiftUI 內容應執行縮放淡入
    static let launchpadWillShow = Notification.Name("LaunchpadWillShow")
    /// 視窗即將以動畫隱藏，SwiftUI 內容應執行縮放淡出
    static let launchpadWillHide = Notification.Name("LaunchpadWillHide")
}

@main
struct Launchpad_BackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class LaunchpadWindow: NSWindow {
    var onCloseRequested: (() -> Void)?

    override func performClose(_ sender: Any?) {
        if let onCloseRequested {
            onCloseRequested()
            return
        }

        super.performClose(sender)
    }

    override func close() {
        if let onCloseRequested {
            onCloseRequested()
            return
        }

        super.close()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let defaultWindowSize = NSSize(width: 1000, height: 700)
    private var globalHotKeyRef: EventHotKeyRef?
    private var globalHotKeyHandlerRef: EventHandlerRef?
    private let globalHotKeySignature: OSType = 0x4C50424B // "LPBK"
    private let globalHotKeyID: UInt32 = 1
    
    private var mainWindow: NSWindow?

    // MARK: - 開關動畫狀態
    private let showAnimationDuration: TimeInterval = 0.22
    private let hideAnimationDuration: TimeInterval = 0.18
    private var isHidingAnimated = false
    private var hideGeneration = 0

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
        false
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        clampedFrameSize(for: sender, proposedSize: frameSize)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === mainWindow else {
            return
        }

        let clampedSize = clampedFrameSize(for: window, proposedSize: window.frame.size)
        guard window.frame.size != clampedSize else {
            return
        }

        let adjustedOrigin = NSPoint(
            x: window.frame.maxX - clampedSize.width,
            y: window.frame.origin.y
        )
        window.setFrame(NSRect(origin: adjustedOrigin, size: clampedSize), display: true)
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
        hideMainWindow(animated: true)
    }

    func hideMainWindow(animated: Bool) {
        guard let window = mainWindow else {
            Logger.warning("No main window found")
            return
        }

        guard window.isVisible else { return }

        guard animated else {
            isHidingAnimated = false
            hideGeneration &+= 1
            window.orderOut(nil)
            window.alphaValue = 1
            logWindowState(window, context: "hide")
            Logger.info("Window hidden")
            return
        }

        // 已經在做隱藏動畫就不重複觸發
        guard !isHidingAnimated else { return }

        isHidingAnimated = true
        hideGeneration &+= 1
        let generation = hideGeneration

        NotificationCenter.default.post(name: .launchpadWillHide, object: nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = hideAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            // 動畫途中若又被叫出視窗，generation 會不同，此時放棄隱藏
            guard self.isHidingAnimated, generation == self.hideGeneration else { return }

            self.isHidingAnimated = false
            window.orderOut(nil)
            window.alphaValue = 1
            self.logWindowState(window, context: "hide")
            Logger.info("Window hidden")
        })
    }

    func closeMainWindow() {
        guard mainWindow != nil else {
            Logger.warning("No main window found")
            return
        }

        hideMainWindow()
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

        // 視窗尚未顯示（或正在做隱藏動畫）才需要播放顯示動畫
        let needsShowAnimation = !window.isVisible || isHidingAnimated

        // 取消進行中的隱藏動畫
        isHidingAnimated = false
        hideGeneration &+= 1

        if needsShowAnimation {
            window.alphaValue = 0
        }

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)

        if needsShowAnimation {
            NotificationCenter.default.post(name: .launchpadWillShow, object: nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = showAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        } else {
            window.alphaValue = 1
        }

        logWindowState(window, context: "show")
        Logger.info("Window shown")
    }

    func toggleMainWindowVisibility() {
        guard let window = mainWindow else {
            showMainWindow()
            return
        }

        logWindowState(window, context: "toggle")

        // 隱藏動畫進行中視為「已隱藏」，再按快捷鍵應該重新叫出
        if isHidingAnimated {
            showMainWindow()
        } else if shouldHideWindow(window) {
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
        let window = LaunchpadWindow(
            contentRect: NSRect(origin: .zero, size: defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.setContentSize(defaultWindowSize)
        window.setFrame(NSRect(origin: .zero, size: defaultWindowSize), display: false)
        window.contentMinSize = GridLayoutManager.minimumWindowContentSize
        window.minSize = minimumWindowFrameSize(for: window)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isRestorable = false
        window.onCloseRequested = { [weak self] in
            self?.hideMainWindow()
        }
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
        
        if window.contentLayoutRect.width < GridLayoutManager.minimumWindowContentSize.width ||
            window.contentLayoutRect.height < GridLayoutManager.minimumWindowContentSize.height {
            window.setContentSize(defaultWindowSize)
            Logger.info("Corrected zero-sized window frame")
        }
    }

    private func minimumWindowFrameSize(for window: NSWindow) -> NSSize {
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: GridLayoutManager.minimumWindowContentSize)).size
        return NSSize(width: ceil(frameSize.width), height: ceil(frameSize.height))
    }

    private func clampedFrameSize(for window: NSWindow, proposedSize: NSSize) -> NSSize {
        let minimumFrameSize = minimumWindowFrameSize(for: window)
        return NSSize(
            width: max(proposedSize.width, minimumFrameSize.width),
            height: max(proposedSize.height, minimumFrameSize.height)
        )
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
