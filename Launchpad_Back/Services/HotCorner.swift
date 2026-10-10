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
            updateCornerPoints()
        }
    }

    /// How close to the corner counts as reaching it, and how far the pointer must leave before it fires again.
    private let reach: CGFloat = 2
    private let rearmDistance: CGFloat = 40

    private var monitors: [Any] = []
    private var screenObserver: Any?
    private var armed = true
    /// The chosen corner of every screen. Pointer moves arrive constantly, so screens aren't queried per event.
    private var cornerPoints: [CGPoint] = []

    private init() {}

    private func start() {
        guard monitors.isEmpty else { return }
        armed = true
        updateCornerPoints()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateCornerPoints() }
        // Global events come from other apps (no permission needed for pointer movement),
        // local ones from Launchpad itself.
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.pointerMoved()
            },
            NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.pointerMoved()
                return event
            },
        ].compactMap { $0 }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    private func updateCornerPoints() {
        cornerPoints = NSScreen.screens.compactMap { cornerPoint(of: $0.frame) }
    }

    private func pointerMoved() {
        let location = NSEvent.mouseLocation
        var distance = CGFloat.greatestFiniteMagnitude
        for point in cornerPoints {
            distance = min(distance, max(abs(location.x - point.x), abs(location.y - point.y)))
        }
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
