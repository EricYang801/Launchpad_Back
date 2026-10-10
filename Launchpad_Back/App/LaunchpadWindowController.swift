import AppKit
import SwiftUI

/// A borderless window can't become key by default, which would leave the search field without keyboard input.
private final class LaunchpadWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the full-screen Launchpad window: which screen it covers, the open/close animation, and its input.
final class LaunchpadWindowController: NSObject, NSDraggingSource {
    let store: LaunchpadStore
    var openSettings: () -> Void = {}

    private let window: NSWindow
    private var input: InputMonitor?

    var isShown: Bool { window.isVisible && store.isPresented }

    init(store: LaunchpadStore) {
        self.store = store
        window = LaunchpadWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        // Just below the Dock, like Launchpad: the Dock stays usable and apps can be dragged onto it.
        // The menu bar is above too, so the app menu (Settings…) stays clickable.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        // Lets the hot corner see the pointer while Launchpad itself is in front.
        window.acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(rootView: LaunchpadView(store: store))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        super.init()

        store.dismiss = { [weak self] in self?.hide() }
        store.dragToDock = { [weak self] app in self?.beginDockDrag(app) ?? false }
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
        store.dock = .current(on: screen)
        window.setFrame(screen.frame, display: false)

        NSApp.unhide(nil)
        // The hot corner and the trackpad gesture aren't events this app receives, so the cooperative
        // `activate()` is refused for them; the forced variant still brings Launchpad to the front.
        NSApp.activate(ignoringOtherApps: true)
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

    // MARK: - Dragging to the Dock

    /// Turns the in-window drag into a system drag of the app's file URL, which the Dock accepts.
    private func beginDockDrag(_ app: AppItem) -> Bool {
        guard let view = window.contentView, let event = input?.lastMouseDragged else { return false }
        let size = store.metrics.iconSize
        let icon = IconCache.shared.cachedIcon(for: app.url, pixels: IconCache.pixels(for: size))
            ?? NSWorkspace.shared.icon(forFile: app.url.path)
        let point = view.convert(event.locationInWindow, from: nil)
        let item = NSDraggingItem(pasteboardWriter: app.url as NSURL)
        item.setDraggingFrame(NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size), contents: icon)
        view.beginDraggingSession(with: [item], event: event, source: self)
        return true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Offer only a link, and only over the Dock: the Dock keeps a reference, a drop on Finder can never copy or
        // move the app bundle, and the Trash (which wants a move) refuses it.
        context == .outsideApplication && isOverDock(NSEvent.mouseLocation) ? .link : []
    }

    private func isOverDock(_ point: NSPoint) -> Bool {
        guard let screen = window.screen else { return false }
        let zone = store.dock.handoffZone(in: screen.frame.size)
        // The zone is in window coordinates (top-left origin); convert the global point to match.
        let local = NSPoint(x: point.x - screen.frame.minX, y: screen.frame.maxY - point.y)
        return zone.insetBy(dx: 0, dy: -8).contains(local)
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        store.dockDragEnded()
    }
}

extension DockPlacement {
    /// Reads the Dock's side from its preferences and its size from what it takes off the screen's visible frame.
    static func current(on screen: NSScreen) -> DockPlacement {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let edge: Edge = switch UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") {
        case "left": .left
        case "right": .right
        default: .bottom
        }
        let thickness = switch edge {
        case .bottom: visible.minY - frame.minY
        case .left: visible.minX - frame.minX
        case .right: frame.maxX - visible.maxX
        }
        return DockPlacement(edge: edge, thickness: max(thickness, 0))
    }
}
