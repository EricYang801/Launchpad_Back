import AppKit
import SwiftUI

/// A borderless window can't become key by default, which would leave the search field without keyboard input.
private final class LaunchpadWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the full-screen Launchpad window: which screen it covers, the open/close animation, and its input.
final class LaunchpadWindowController {
    let store: LaunchpadStore
    var openSettings: () -> Void = {}

    private let window: NSWindow
    private var input: InputMonitor?

    var isShown: Bool { window.isVisible && store.isPresented }

    init(store: LaunchpadStore) {
        self.store = store
        window = LaunchpadWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        // Above the Dock but below the menu bar, so the app menu (Settings…) stays clickable.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none

        let hostingView = NSHostingView(rootView: LaunchpadView(store: store))
        hostingView.sizingOptions = []
        window.contentView = hostingView

        store.dismiss = { [weak self] in self?.hide() }
        input = InputMonitor(store: store, window: window, openSettings: { [weak self] in self?.openSettings() })
    }

    func toggle() {
        isShown ? hide() : show()
    }

    func show() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        store.prepareForPresentation()
        store.size = screen.frame.size
        window.setFrame(screen.frame, display: false)

        NSApp.unhide(nil)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        input?.start()

        withAnimation(.easeOut(duration: 0.25)) { store.isPresented = true }
        Task {
            store.backdrop = await Wallpaper.blurred(for: screen)
            await store.reload()
        }
    }

    /// `returnFocus` hands activation back to the previous app, as Launchpad does when dismissed.
    func hide(animated: Bool = true, returnFocus: Bool = true) {
        guard window.isVisible, store.isPresented else { return }
        input?.stop()
        withAnimation(.easeIn(duration: animated ? 0.2 : 0)) {
            store.isPresented = false
        } completion: { [weak self] in
            // Shown again while fading out: keep the window.
            guard let self, !self.store.isPresented else { return }
            self.window.orderOut(nil)
            if returnFocus, NSApp.isActive { NSApp.hide(nil) }
        }
    }
}
