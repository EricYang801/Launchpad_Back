//
//  AppIconView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import AppKit

// MARK: - 抖動動畫修飾器

/// 編輯模式抖動效果
struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    @State private var wiggleAngle: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? wiggleAngle : 0))
            .onAppear {
                if isWiggling {
                    startWiggle()
                }
            }
            .onChange(of: isWiggling) { _, newValue in
                if newValue {
                    startWiggle()
                } else {
                    wiggleAngle = 0
                }
            }
    }
    
    private func startWiggle() {
        // 隨機化抖動，讓每個圖標抖動看起來不同步
        let randomDelay = Double.random(in: 0...0.1)
        let randomAmplitude = Double.random(in: 2.5...3.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
            withAnimation(
                .easeInOut(duration: 0.1)
                .repeatForever(autoreverses: true)
            ) {
                wiggleAngle = randomAmplitude
            }
        }
    }
}

extension View {
    func wiggle(_ isWiggling: Bool) -> some View {
        modifier(WiggleModifier(isWiggling: isWiggling))
    }
}

// MARK: - 共用的交互式圖標容器（消除重複代碼）

/// 交互式圖標配置
struct InteractiveIconConfig {
    let name: String
    let isDragging: Bool
    let isEditing: Bool
    let isDropTarget: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    let onDragChanged: ((CGPoint) -> Void)?
    let onDragEnded: (() -> Void)?
}

/// 交互式圖標容器 ViewModifier - 提取共用邏輯
struct InteractiveIconModifier: ViewModifier {
    let config: InteractiveIconConfig
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    
    func body(content: Content) -> some View {
        content
            .wiggle(config.isEditing && !config.isDragging)
            .opacity(config.isDragging ? 0.3 : 1.0)
            .overlay(dropTargetOverlay)
            .offset(dragOffset)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .simultaneousGesture(tapGesture)
            .simultaneousGesture(longPressGesture)
            .simultaneousGesture(editDragGesture)
    }
    
    // MARK: - 手勢
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                // 編輯模式下也允許點擊（讓調用者決定如何處理）
                isPressed = true
                config.onTap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isPressed = false
                }
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                Logger.info("Long press detected on \(config.name)")
                config.onLongPress?()
            }
    }
    
    private var editDragGesture: some Gesture {
        DragGesture(minimumDistance: config.isEditing ? 5 : 1000, coordinateSpace: .global)
            .onChanged { value in
                if config.isEditing {
                    dragOffset = value.translation
                    config.onDragChanged?(value.location)
                }
            }
            .onEnded { _ in
                if config.isEditing {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                    config.onDragEnded?()
                }
            }
    }
    
    // MARK: - UI 組件
    
    @ViewBuilder
    private var dropTargetOverlay: some View {
        if config.isDropTarget {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: GridLayoutManager.iconSize + 10, height: GridLayoutManager.iconSize + 10)
                .offset(y: -8)
        }
    }
}

/// 計算縮放值的工具函數
func calculateScaleValue(isDropTarget: Bool, isDragging: Bool, isPressed: Bool, isHovered: Bool) -> CGFloat {
    if isDropTarget {
        return 1.2
    } else if isDragging {
        return 1.1
    } else if isPressed {
        return 0.85
    } else if isHovered {
        return 1.08
    }
    return 1.0
}

// MARK: - 圖標圖片容器

/// 共用的圖標圖片視圖（帶動畫和陰影）
struct IconImageContainer<Content: View>: View {
    let isDropTarget: Bool
    let isDragging: Bool
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        content()
            .frame(width: GridLayoutManager.iconSize, height: GridLayoutManager.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.2), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
            .scaleEffect(calculateScaleValue(isDropTarget: isDropTarget, isDragging: isDragging, isPressed: isPressed, isHovered: isHovered))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: isPressed)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDropTarget)
            .onHover { isHovered = $0 }
    }
}

/// 圖標標籤視圖
struct IconLabelView: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(width: GridLayoutManager.labelMaxWidth, height: GridLayoutManager.labelHeight, alignment: .top)
    }
}

// MARK: - 單個應用程式圖示視圖

/// 單個應用程式圖示視圖
struct AppIconView: View {
    let app: AppItem
    let onTap: () -> Void
    var isDragging: Bool = false
    var isEditing: Bool = false
    var isDropTarget: Bool = false
    var onLongPress: (() -> Void)?
    var onDragStarted: ((CGPoint) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖示
            IconImageContainer(isDropTarget: isDropTarget, isDragging: isDragging) {
                if let icon = app.appIcon, icon.size.width > 0 {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    defaultIconView
                }
            }
            
            // 應用程式名稱
            IconLabelView(name: app.name)
        }
        .modifier(InteractiveIconModifier(config: InteractiveIconConfig(
            name: app.name,
            isDragging: isDragging,
            isEditing: isEditing,
            isDropTarget: isDropTarget,
            onTap: onTap,
            onLongPress: onLongPress,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )))
    }
    
    private var defaultIconView: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.4),
                    Color.gray.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                Image(systemName: "app.dashed")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

/// 文件夾圖示視圖
struct FolderIconView: View {
    let folder: AppFolder
    let onTap: () -> Void
    var isDragging: Bool = false
    var isEditing: Bool = false
    var isDropTarget: Bool = false
    var onLongPress: (() -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            // 文件夾圖示（3x3 網格預覽）
            IconImageContainer(isDropTarget: isDropTarget, isDragging: isDragging) {
                folderIconGrid
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            // 文件夾名稱
            IconLabelView(name: folder.name)
        }
        .modifier(InteractiveIconModifier(config: InteractiveIconConfig(
            name: folder.name,
            isDragging: isDragging,
            isEditing: isEditing,
            isDropTarget: isDropTarget,
            onTap: onTap,
            onLongPress: onLongPress,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )))
    }
    
    private var folderIconGrid: some View {
        let iconSize: CGFloat = 22
        let spacing: CGFloat = 4
        let padding: CGFloat = 8
        
        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(iconSize), spacing: spacing), count: 3),
            spacing: spacing
        ) {
            ForEach(0..<9, id: \.self) { index in
                if index < folder.apps.count {
                    if let icon = folder.apps[index].appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        emptySlot(size: iconSize)
                    }
                } else {
                    emptySlot(size: iconSize)
                }
            }
        }
        .padding(padding)
    }
    
    private func emptySlot(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(.clear)
            .frame(width: size, height: size)
    }
}

/// Launchpad 項目視圖（支持應用和文件夾）
struct LaunchpadItemView: View {
    let item: LaunchpadDisplayItem
    let onAppTap: (AppItem) -> Void
    let onFolderTap: (AppFolder) -> Void
    var isDragging: Bool = false
    var isEditing: Bool = false
    var isDropTarget: Bool = false
    var onLongPress: (() -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    var body: some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                onTap: { onAppTap(app) },
                isDragging: isDragging,
                isEditing: isEditing,
                isDropTarget: isDropTarget,
                onLongPress: onLongPress,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
        case .folder(let folder):
            FolderIconView(
                folder: folder,
                onTap: { onFolderTap(folder) },
                isDragging: isDragging,
                isEditing: isEditing,
                isDropTarget: isDropTarget,
                onLongPress: onLongPress,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
        }
    }
}

#Preview {
    let sampleApp = AppItem(name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: false)
    AppIconView(app: sampleApp) {}
}
