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
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isLongPressing = false
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖示
            Group {
                if let icon = app.appIcon, icon.size.width > 0 {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    defaultIconView
                }
            }
            .frame(width: GridLayoutManager.iconSize, height: GridLayoutManager.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.2), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
            .scaleEffect(scaleValue)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: isPressed)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDropTarget)
            
            // 應用程式名稱
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: GridLayoutManager.labelMaxWidth, height: GridLayoutManager.labelHeight, alignment: .top)
        }
        .wiggle(isEditing && !isDragging)
        .opacity(isDragging ? 0.3 : 1.0)
        .overlay(dropTargetOverlay)
        .offset(dragOffset)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard !isEditing else { return }
                    isPressed = true
                    onTap()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isPressed = false
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Logger.info("Long press detected on \(app.name)")
                    onLongPress?()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: isEditing ? 5 : 1000)
                .onChanged { value in
                    if isEditing {
                        dragOffset = value.translation
                        onDragChanged?(value.location)
                        Logger.debug("Dragging \(app.name) to \(value.location)")
                    }
                }
                .onEnded { _ in
                    if isEditing {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                        onDragEnded?()
                        Logger.debug("Drag ended for \(app.name)")
                    }
                }
        )
    }
    
    private var scaleValue: CGFloat {
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
    
    @ViewBuilder
    private var dropTargetOverlay: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: GridLayoutManager.iconSize + 10, height: GridLayoutManager.iconSize + 10)
                .offset(y: -8) // 對齊圖標
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                dragOffset = value.translation
                onDragChanged?(value.location)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = .zero
                }
                onDragEnded?()
            }
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
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 8) {
            // 文件夾圖示（3x3 網格預覽）
            folderIconGrid
                .frame(width: GridLayoutManager.iconSize, height: GridLayoutManager.iconSize)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.2), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
                .scaleEffect(scaleValue)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .animation(.spring(response: 0.15, dampingFraction: 0.8), value: isPressed)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDropTarget)
            
            // 文件夾名稱
            Text(folder.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: GridLayoutManager.labelMaxWidth, height: GridLayoutManager.labelHeight, alignment: .top)
        }
        .wiggle(isEditing && !isDragging)
        .opacity(isDragging ? 0.3 : 1.0)
        .overlay(dropTargetOverlay)
        .offset(dragOffset)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard !isEditing else { return }
                    isPressed = true
                    onTap()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isPressed = false
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Logger.info("Long press detected on folder \(folder.name)")
                    onLongPress?()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: isEditing ? 5 : 1000)
                .onChanged { value in
                    if isEditing {
                        dragOffset = value.translation
                        onDragChanged?(value.location)
                    }
                }
                .onEnded { _ in
                    if isEditing {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                        onDragEnded?()
                    }
                }
        )
    }
    
    private var scaleValue: CGFloat {
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
    
    @ViewBuilder
    private var dropTargetOverlay: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: GridLayoutManager.iconSize + 10, height: GridLayoutManager.iconSize + 10)
                .offset(y: -8)
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                dragOffset = value.translation
                onDragChanged?(value.location)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = .zero
                }
                onDragEnded?()
            }
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
