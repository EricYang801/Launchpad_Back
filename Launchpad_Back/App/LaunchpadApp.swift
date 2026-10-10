import AppKit
import SwiftUI

@main
struct LaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The Launchpad and Settings windows are AppKit windows owned by the delegate;
        // this scene only exists to route the standard "Settings…" menu item there.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.showSettings() }
                        .keyboardShortcut(",")
                }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private lazy var launchpad = LaunchpadWindowController(store: LaunchpadStore(preferences: preferences))
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests use the app as their host; don't take over the screen or the shortcut.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        NSApp.setActivationPolicy(preferences.showsDockIcon ? .regular : .accessory)
        launchpad.openSettings = { [weak self] in self?.showSettings() }

        GlobalHotKey.shared.action = { [weak self] in self?.launchpad.toggle() }
        GlobalHotKey.shared.register(preferences.hotKey)

        TrackpadPinch.shared.onPinch = { [weak self] in
            guard let self, !self.launchpad.isShown else { return }
            self.launchpad.show()
        }
        TrackpadPinch.shared.onSpread = { [weak self] in self?.launchpad.hide() }
        TrackpadPinch.shared.isEnabled = preferences.pinchGesture

        HotCorner.shared.action = { [weak self] in self?.launchpad.toggle() }
        HotCorner.shared.corner = preferences.hotCorner

        launchpad.show()
    }

    /// Clicking the Dock icon, or opening the app again from Finder, toggles Launchpad.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        launchpad.toggle()
        return false
    }

    /// Clicking another app or the desktop closes Launchpad.
    func applicationDidResignActive(_ notification: Notification) {
        launchpad.hide()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        launchpad.hide(animated: false, returnFocus: false)
        if settingsWindow == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(
                    rootView: SettingsView(preferences: preferences) { [weak self] in
                        self?.launchpad.store.resetLayout()
                    }))
            window.title = String(localized: "Launchpad Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.unhide(nil)
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
