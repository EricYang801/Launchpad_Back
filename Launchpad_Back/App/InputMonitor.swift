import AppKit

/// Keyboard, trackpad and mouse-wheel handling for the Launchpad window.
final class InputMonitor {
    private let store: LaunchpadStore
    private weak var window: NSWindow?
    private let openSettings: () -> Void
    private var monitors: [Any] = []
    /// The latest mouse-drag event in the window; a system drag to the Dock has to start from one.
    private(set) var lastMouseDragged: NSEvent?

    private var swipeDistance: CGFloat = 0
    private var lastSwipeDelta: CGFloat = 0
    private var wheelDistance: CGFloat = 0
    private var lastWheelPage = Date.distantPast

    init(store: LaunchpadStore, window: NSWindow, openSettings: @escaping () -> Void) {
        self.store = store
        self.window = window
        self.openSettings = openSettings
    }

    func start() {
        guard monitors.isEmpty else { return }
        monitors = [
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.key(event)
            },
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                return self.scroll(event)
            },
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                if event.window === self?.window { self?.lastMouseDragged = event }
                return event
            },
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                // Drop on mouse-up even if SwiftUI dropped the drag gesture along the way.
                if event.window === self?.window { self?.store.endDrag() }
                return event
            },
        ].compactMap { $0 }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        lastMouseDragged = nil
    }

    private func key(_ event: NSEvent) -> NSEvent? {
        guard let window, event.window === window else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "w": store.dismiss()
            case "q": NSApp.terminate(nil)
            case ",": openSettings()
            default: return event
            }
            return nil
        }

        let renaming = store.isRenaming
        switch event.keyCode {
        case 53: store.escape(); return nil
        case 36, 76: return !renaming && store.handle(.enter) ? nil : event
        case 123: return !renaming && store.handle(.left) ? nil : event
        case 124: return !renaming && store.handle(.right) ? nil : event
        case 125: return !renaming && store.handle(.down) ? nil : event
        case 126: return !renaming && store.handle(.up) ? nil : event
        default: break
        }

        // Type anywhere to search: send keys to the search field when no text field has focus.
        let isEditingText = window.firstResponder is NSTextView
        if !isEditingText, !flags.contains(.control), let characters = event.characters,
           let scalar = characters.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar), !(0xF700...0xF8FF).contains(scalar.value) {
            store.query += characters
            // Focusing the field selects its text; put the caret at the end so the next key doesn't replace it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak window] in
                (window?.firstResponder as? NSTextView)?.moveToEndOfDocument(nil)
            }
            return nil
        }
        return event
    }

    private func scroll(_ event: NSEvent) -> NSEvent? {
        guard event.window === window, store.drag == nil else { return event }

        if event.hasPreciseScrollingDeltas {
            // Trackpad: the page follows the fingers, then snaps. Momentum events are ignored.
            guard event.momentumPhase.isEmpty else { return nil }
            let delta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
            if event.phase.contains(.began) {
                swipeDistance = 0
                lastSwipeDelta = 0
            } else if event.phase.contains(.changed) {
                swipeDistance += delta
                lastSwipeDelta = delta
                store.swipeChanged(swipeDistance)
            } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                store.swipeEnded(swipeDistance, velocity: lastSwipeDelta * 12)
                swipeDistance = 0
            }
        } else {
            // Mouse wheel: one notch turns one page.
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.scrollingDeltaX
            wheelDistance += delta
            if abs(wheelDistance) >= 1, Date().timeIntervalSince(lastWheelPage) > 0.35 {
                store.movePage(by: wheelDistance > 0 ? -1 : 1)
                lastWheelPage = Date()
                wheelDistance = 0
            }
        }
        return nil
    }
}
