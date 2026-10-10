import AppKit

/// Launchpad's trackpad gesture: pinch the thumb and three fingers together to open, spread them to close.
/// Only exactly four fingers count; five-finger pinches are left to macOS.
///
/// Apps only receive two-finger pinches, so this reads raw touches from the private MultitouchSupport
/// framework, loaded at runtime. If it is missing the gesture is simply unavailable.
final class TrackpadPinch {
    static let shared = TrackpadPinch()

    var onPinch: () -> Void = {}
    var onSpread: () -> Void = {}

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    private var devices: [UnsafeMutableRawPointer] = []
    private var deviceList: CFArray?
    private var wakeObserver: Any?

    private init() {}

    private func start() {
        guard let api = MultitouchAPI.shared else { return }
        PinchDetector.shared.handler = { [weak self] gesture in
            DispatchQueue.main.async {
                guard let self, self.isEnabled else { return }
                gesture == .pinch ? self.onPinch() : self.onSpread()
            }
        }
        guard let list = api.createList()?.takeRetainedValue() else { return }
        deviceList = list
        devices = (0..<CFArrayGetCount(list)).compactMap {
            UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, $0))
        }
        for device in devices {
            api.register(device, contactCallback)
            _ = api.start(device, 0)
        }
        // Touch devices stop reporting after sleep; reconnect on wake.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isEnabled else { return }
            self.stop()
            self.start()
        }
    }

    private func stop() {
        if let api = MultitouchAPI.shared {
            for device in devices {
                api.unregister(device, contactCallback)
                api.stop(device)
            }
        }
        devices = []
        deviceList = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
    }
}

// MARK: - MultitouchSupport

private typealias ContactCallback =
    @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

/// Called on the framework's own thread with every frame of touches.
private let contactCallback: ContactCallback = { _, touches, count, _, _ in
    PinchDetector.shared.process(touches, count: Int(count))
    return 0
}

private nonisolated struct MultitouchAPI: @unchecked Sendable {
    typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    typealias Register = @convention(c) (UnsafeMutableRawPointer?, ContactCallback?) -> Void
    typealias Start = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32
    typealias Stop = @convention(c) (UnsafeMutableRawPointer?) -> Void

    let createList: CreateList
    let register: Register
    let unregister: Register
    let start: Start
    let stop: Stop

    static let shared: MultitouchAPI? = {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
        func symbol<T>(_ name: String, as _: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
        }
        guard let createList = symbol("MTDeviceCreateList", as: CreateList.self),
            let register = symbol("MTRegisterContactFrameCallback", as: Register.self),
            let unregister = symbol("MTUnregisterContactFrameCallback", as: Register.self),
            let start = symbol("MTDeviceStart", as: Start.self),
            let stop = symbol("MTDeviceStop", as: Stop.self)
        else { return nil }
        return MultitouchAPI(
            createList: createList, register: register, unregister: unregister, start: start, stop: stop)
    }()
}

/// Turns touch frames into pinch / spread events. Only touched from the framework's callback thread,
/// apart from `handler`, which is set before any device starts.
private nonisolated final class PinchDetector: @unchecked Sendable {
    enum Gesture { case pinch, spread }

    static let shared = PinchDetector()

    var handler: (Gesture) -> Void = { _ in }

    /// Layout of the framework's touch record: 96 bytes, normalized position at byte 32, state at byte 20.
    private static let stride = 96
    private static let stateOffset = 20
    private static let positionOffset = 32
    /// States 4 and 5 mean the finger is on the surface.
    private static let touchingStates: ClosedRange<Int32> = 4...5

    private var startSpread: Float?
    private var fired = false

    /// Runs for every touch frame, about 100 a second whenever a finger is down (ordinary scrolling included),
    /// so it allocates nothing and bails out as early as it can.
    func process(_ touches: UnsafeMutableRawPointer?, count: Int) {
        var touching = 0
        var xs = SIMD4<Float>()
        var ys = SIMD4<Float>()
        if let touches {
            for index in 0..<count {
                let touch = touches + index * Self.stride
                guard Self.touchingStates.contains(touch.load(fromByteOffset: Self.stateOffset, as: Int32.self)) else {
                    continue
                }
                if touching < 4 {
                    xs[touching] = touch.load(fromByteOffset: Self.positionOffset, as: Float.self)
                    ys[touching] = touch.load(fromByteOffset: Self.positionOffset + 4, as: Float.self)
                }
                touching += 1
            }
        }

        // All fingers lifted: the next four-finger contact is a new gesture.
        if touching <= 1 {
            startSpread = nil
            fired = false
            return
        }
        // Exactly the thumb and three fingers. A fifth finger rules out the whole gesture until the hand lifts,
        // so a five-finger pinch never opens Launchpad.
        if touching > 4 { fired = true }
        guard touching == 4, !fired else { return }

        let dx = xs - xs.sum() / 4
        let dy = ys - ys.sum() / 4
        let spread = (dx * dx + dy * dy).squareRoot().sum() / 4

        guard let startSpread else {
            startSpread = spread
            return
        }
        guard startSpread > 0.01 else { return }
        let ratio = spread / startSpread
        if ratio < 0.6 {
            fired = true
            handler(.pinch)
        } else if ratio > 1.5 {
            fired = true
            handler(.spread)
        }
    }
}
