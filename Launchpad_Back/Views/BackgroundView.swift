//
//  BackgroundView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import AppKit

/// Launchpad 風格的半透明背景（更接近原版）
struct BackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        // 使用 fullScreenUI 材質來獲得更深的模糊效果
        visualEffectView.material = .fullScreenUI
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        
        // 添加深色覆蓋層以增強效果
        if let layer = visualEffectView.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        }
        
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 保持背景狀態
    }
}

/// 漸變背景覆蓋層
struct GradientOverlay: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.2),
                Color.black.opacity(0.1),
                Color.black.opacity(0.2)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// 組合背景視圖
struct LaunchpadBackgroundView: View {
    var body: some View {
        ZStack {
            BackgroundView()
            GradientOverlay()
        }
        .ignoresSafeArea()
    }
}
