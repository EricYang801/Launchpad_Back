import AppKit

/// A screen corner that toggles Launchpad when the pointer reaches it.
nonisolated enum ScreenCorner: String, CaseIterable, Identifiable, Sendable {
    case off, topLeft, topRight, bottomLeft, bottomRight

    var id: Self { self }
}

/// Watches the pointer and fires once each time it enters the chosen corner of any screen.
final class HotCorner {
    static let shared = HotCorner()

    var action: () -> Void = {}

    var corner = ScreenCorner.off {
        didSet {
            guard corner != oldValue else { return }
            corner == .off ? stop() : start()
        }
    }

    /// How close to the corner counts as reaching it, and how far the pointer must leave before it fires again.
    private let reach: CGFloat = 2
    private let rearmDistance: CGFloat = 40

    private var monitors: [Any] = []
    private var armed = true

    private init() {}

    private func start() {
        guard monitors.isEmpty else { return }
        armed = true
        // Global events come from other apps (no permission needed for pointer movement); local ones from Launchpad itself.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in self?.pointerMoved() }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            self?.pointerMoved()
            return event
        }) {
            monitors.append(local)
        }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private func pointerMoved() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }),
              let point = cornerPoint(of: screen.frame) else { return }
        let distance = max(abs(location.x - point.x), abs(location.y - point.y))
        if armed, distance <= reach {
            armed = false
            action()
        } else if !armed, distance > rearmDistance {
            armed = true
        }
    }

    /// In AppKit's global coordinates, where y grows upwards.
    private func cornerPoint(of frame: CGRect) -> CGPoint? {
        switch corner {
        case .off: nil
        case .topLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.maxY)
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.minY)
        }
    }
}
