//
//  TouchpadScrollView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import AppKit

/// 檢測觸控板滾動事件的視圖
struct TouchpadScrollView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> ScrollDetectorView {
        let view = ScrollDetectorView()
        view.scrollCallback = onScroll
        return view
    }
    
    func updateNSView(_ nsView: ScrollDetectorView, context: Context) {
        nsView.scrollCallback = onScroll
    }
}

/// 檢測滾輪事件的自定義 NSView
class ScrollDetectorView: NSView {
    var scrollCallback: ((CGFloat) -> Void)?
    private var lastScrollTime: CFTimeInterval = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        allowedTouchTypes = [.direct, .indirect]
    }
    
    override func scrollWheel(with event: NSEvent) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - lastScrollTime > 0.05 else { return }
        lastScrollTime = currentTime
        
        let deltaX = event.scrollingDeltaX
        if abs(deltaX) > 1.0 {
            DispatchQueue.main.async {
                self.scrollCallback?(deltaX)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        window?.makeFirstResponder(self)
    }
}
