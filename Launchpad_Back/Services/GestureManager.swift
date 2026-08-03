//
//  GestureManager.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 滾動設備類型
enum ScrollDeviceType {
    case trackpad   // 觸控板（有精確的 delta 值和手勢階段）
    case mouse      // 滑鼠滾輪（離散的 notch 步進）
}

/// 手勢管理器
/// 負責監聽和處理滾輪和拖動事件
/// - 觸控板：連續回報累積位移，讓頁面即時跟隨手指移動（貼近原版 Launchpad）
/// - 滑鼠滾輪：離散 notch 步進，直接觸發翻頁
class GestureManager {
    private var scrollMonitor: Any?
    private let onPageChange: (Int) -> Void  // 傳遞 -1（上一頁）或 +1（下一頁），用於滑鼠滾輪

    /// 觸控板滑動進行中：回報累積位移（正值 = 向右滑，頁面應跟著往右移）
    var onTrackpadScrollChanged: ((CGFloat) -> Void)?
    /// 觸控板滑動結束：回報（累積位移, 最後一筆位移）讓呼叫端決定翻頁或彈回
    var onTrackpadScrollEnded: ((CGFloat, CGFloat) -> Void)?

    // MARK: - 觸控板專用狀態
    private var trackpadAccumulatedDelta: CGFloat = 0
    private var trackpadLastDelta: CGFloat = 0
    private var isTrackpadGestureActive = false

    // MARK: - 滑鼠滾輪專用狀態
    private var mouseAccumulatedNotches: CGFloat = 0
    private var lastMouseScrollTime: CFTimeInterval = 0
    private let mouseDebounceInterval: CFTimeInterval = 0.3  // 滑鼠滾輪的防抖間隔
    private let mouseNotchThreshold: CGFloat = 3.0  // 滑鼠需要累積幾個 notch

    // MARK: - 通用防重複觸發（滑鼠滾輪用）
    private var lastPageChangeTime: CFTimeInterval = 0
    private let pageChangeCooldown: CFTimeInterval = 0.4  // 頁面切換後的冷卻時間

    init(onPageChange: @escaping (Int) -> Void) {
        self.onPageChange = onPageChange
    }

    /// 開始監聽滾輪事件
    func startListening() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }
        Logger.debug("GestureManager started listening")
    }

    /// 停止監聽滾輪事件
    func stopListening() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        Logger.debug("GestureManager stopped listening")
    }

    private func handleScrollEvent(_ event: NSEvent) {
        // 只處理發往主 Launchpad 視窗的事件（避免干擾設定視窗等其他視窗）
        if let window = event.window, !(window is LaunchpadWindow) {
            return
        }

        // 使用 hasPreciseScrollingDeltas 區分設備類型
        // 觸控板 = true（精確的像素級位移）
        // 滑鼠滾輪 = false（離散的行/notch 單位）
        let deviceType: ScrollDeviceType = event.hasPreciseScrollingDeltas ? .trackpad : .mouse

        switch deviceType {
        case .trackpad:
            handleTrackpadScroll(event)
        case .mouse:
            handleMouseScroll(event)
        }
    }

    // MARK: - 觸控板處理（連續跟手，放開後由呼叫端決定翻頁）

    private func handleTrackpadScroll(_ event: NSEvent) {
        // 忽略慣性階段：手指離開後頁面已交由 SwiftUI 動畫 snap
        guard event.momentumPhase == [] else { return }

        let phase = event.phase

        // 主要使用水平滑動
        var delta = event.scrollingDeltaX

        // 如果水平位移很小，也可以考慮垂直滑動（某些用戶習慣）
        if abs(delta) < 1.0 && abs(event.scrollingDeltaY) > abs(delta) {
            delta = -event.scrollingDeltaY  // 垂直轉水平（向上滑 = 向左）
        }

        if phase == .began {
            trackpadAccumulatedDelta = 0
            trackpadLastDelta = 0
            isTrackpadGestureActive = true
            onTrackpadScrollChanged?(0)
            Logger.debug("Trackpad gesture began")
            return
        }

        guard isTrackpadGestureActive else { return }

        if phase == .changed {
            trackpadAccumulatedDelta += delta
            trackpadLastDelta = delta
            onTrackpadScrollChanged?(trackpadAccumulatedDelta)
            return
        }

        if phase == .ended || phase == .cancelled {
            isTrackpadGestureActive = false
            onTrackpadScrollEnded?(trackpadAccumulatedDelta, trackpadLastDelta)
            Logger.debug("Trackpad gesture ended, accumulated: \(trackpadAccumulatedDelta)")
            trackpadAccumulatedDelta = 0
            trackpadLastDelta = 0
        }
    }

    // MARK: - 滑鼠滾輪處理（離散步進）

    private func handleMouseScroll(_ event: NSEvent) {
        let currentTime = CFAbsoluteTimeGetCurrent()

        // 防抖：如果距離上次滾動太久，重置累積值
        if currentTime - lastMouseScrollTime > mouseDebounceInterval {
            mouseAccumulatedNotches = 0
        }
        lastMouseScrollTime = currentTime

        // 滑鼠滾輪的 delta 是以「行」為單位，通常每個 notch 是 1-3
        var notchDelta = event.scrollingDeltaX

        // 某些滑鼠主要使用垂直滾輪
        if abs(notchDelta) < 0.1 && abs(event.scrollingDeltaY) > 0.1 {
            notchDelta = -event.scrollingDeltaY  // 向上滾 = 向左
        }

        // 忽略太小的值（可能是噪音）
        guard abs(notchDelta) > 0.1 else { return }

        mouseAccumulatedNotches += notchDelta

        // 達到閾值時觸發頁面切換
        // 滑鼠滾輪：向右滾=-1(上一頁), 向左滾=+1(下一頁)
        if abs(mouseAccumulatedNotches) >= mouseNotchThreshold {
            let direction = mouseAccumulatedNotches > 0 ? -1 : 1
            triggerPageChange(direction: direction)
            mouseAccumulatedNotches = 0  // 重置
            Logger.debug("Mouse scroll page change triggered, direction: \(direction)")
        }
    }

    // MARK: - 頁面切換（滑鼠滾輪）

    private func triggerPageChange(direction: Int) {
        let currentTime = CFAbsoluteTimeGetCurrent()

        // 冷卻檢查：防止快速連續切換
        guard currentTime - lastPageChangeTime > pageChangeCooldown else {
            Logger.debug("Page change blocked by cooldown")
            return
        }

        lastPageChangeTime = currentTime

        DispatchQueue.main.async { [weak self] in
            self?.onPageChange(direction)
        }
    }

    deinit {
        stopListening()
    }
}
