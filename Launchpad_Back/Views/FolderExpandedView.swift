//
//  FolderExpandedView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import UniformTypeIdentifiers

/// 展開的文件夾視圖
struct FolderExpandedView: View {
    let folder: AppFolder
    let onAppTap: (AppItem) -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void
    let onReorder: (Int, Int) -> Void
    let onRemoveApp: (AppItem) -> Void
    let onStartDragOut: ((AppItem, CGPoint) -> Void)?  // 開始拖出應用（傳遞螢幕位置）
    let onDragOutContinue: ((CGPoint) -> Void)?  // 拖出過程中持續更新位置
    let onDragOutEnd: (() -> Void)?  // 拖出結束
    let initialEditingMode: Bool  // 初始編輯狀態
    
    @State private var folderName: String
    @State private var isEditingName = false
    @State private var isEditingMode: Bool
    @State private var draggingApp: AppItem?
    @State private var dragOutOffset: CGSize = .zero
    @State private var isDraggingOut = false
    @State private var lastDragScreenLocation: CGPoint = .zero
    @State private var hasDraggedOut = false  // 是否已觸發過 dragOut
    @FocusState private var isNameFieldFocused: Bool
    
    private let folderColumns = 4
    
    init(folder: AppFolder, 
         onAppTap: @escaping (AppItem) -> Void, 
         onClose: @escaping () -> Void, 
         onRename: @escaping (String) -> Void,
         onReorder: @escaping (Int, Int) -> Void = { _, _ in },
         onRemoveApp: @escaping (AppItem) -> Void = { _ in },
         onStartDragOut: ((AppItem, CGPoint) -> Void)? = nil,
         onDragOutContinue: ((CGPoint) -> Void)? = nil,
         onDragOutEnd: (() -> Void)? = nil,
         initialEditingMode: Bool = false) {
        self.folder = folder
        self.onAppTap = onAppTap
        self.onClose = onClose
        self.onRename = onRename
        self.onReorder = onReorder
        self.onRemoveApp = onRemoveApp
        self.onStartDragOut = onStartDragOut
        self.onDragOutContinue = onDragOutContinue
        self.onDragOutEnd = onDragOutEnd
        self.initialEditingMode = initialEditingMode
        self._folderName = State(initialValue: folder.name)
        self._isEditingMode = State(initialValue: initialEditingMode)
    }
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(GridLayoutManager.itemWidth), spacing: GridLayoutManager.horizontalSpacing), count: folderColumns)
    }
    
    private var contentWidth: CGFloat {
        let itemsWidth = CGFloat(folderColumns) * GridLayoutManager.itemWidth
        let spacingWidth = CGFloat(folderColumns - 1) * GridLayoutManager.horizontalSpacing
        return itemsWidth + spacingWidth + 48
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩 - 點擊關閉
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if isEditingMode {
                            isEditingMode = false
                        } else {
                            onClose()
                        }
                    }
                
                // 文件夾內容
                folderContentView(geometry: geometry)
            }
        }
        .onAppear {
            // 確保編輯模式狀態正確同步
            if initialEditingMode {
                isEditingMode = true
            }
        }
    }
    
    @ViewBuilder
    private func folderContentView(geometry: GeometryProxy) -> some View {
        let folderFrame = CGRect(
            x: (geometry.size.width - contentWidth) / 2,
            y: (geometry.size.height - 400) / 2,
            width: contentWidth,
            height: 400
        )
        
        VStack(spacing: 12) {
            // 頂部工具欄
            toolbarView
            
            Divider().background(.white.opacity(0.2))
            
            if isEditingMode {
                Text("拖動圖標到外面可移出文件夾")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            // 應用程式網格
            appsGridView(geometry: geometry, folderFrame: folderFrame)
        }
        .padding(.vertical, 20)
        .frame(width: contentWidth)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private var toolbarView: some View {
        HStack {
            folderNameView
            Spacer()
            if isEditingMode {
                Button("完成") {
                    isEditingMode = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.2)))
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func appsGridView(geometry: GeometryProxy, folderFrame: CGRect) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: GridLayoutManager.verticalSpacing) {
                ForEach(Array(folder.apps.enumerated()), id: \.element.id) { index, app in
                    appIconItem(app: app, geometry: geometry, folderFrame: folderFrame)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(maxHeight: 400)
    }
    
    @ViewBuilder
    private func appIconItem(app: AppItem, geometry: GeometryProxy, folderFrame: CGRect) -> some View {
        FolderAppIconView(
            app: app,
            isEditing: isEditingMode,
            isDragging: draggingApp?.id == app.id,
            onTap: {
                if !isEditingMode {
                    onAppTap(app)
                }
            },
            onLongPress: {
                isEditingMode = true
            }
        )
        .offset(draggingApp?.id == app.id ? dragOutOffset : .zero)
        .gesture(
            DragGesture(minimumDistance: isEditingMode ? 5 : 1000, coordinateSpace: .global)
                .onChanged { value in
                    handleDragChange(value: value, app: app, geometry: geometry, folderFrame: folderFrame)
                }
                .onEnded { _ in
                    handleDragEnd()
                }
        )
    }
    
    private func handleDragChange(value: DragGesture.Value, app: AppItem, geometry: GeometryProxy, folderFrame: CGRect) {
        draggingApp = app
        dragOutOffset = value.translation
        lastDragScreenLocation = value.location
        
        // 計算當前拖動位置是否在文件夾外
        let localPos = CGPoint(
            x: value.startLocation.x + value.translation.width,
            y: value.startLocation.y + value.translation.height
        )
        let folderLocalPos = CGPoint(
            x: localPos.x - (geometry.size.width - contentWidth) / 2,
            y: localPos.y
        )
        let expandedFrame = CGRect(x: 0, y: folderFrame.minY, width: contentWidth, height: folderFrame.height)
        let wasInside = !isDraggingOut
        isDraggingOut = !expandedFrame.contains(folderLocalPos)
        
        // 當剛剛離開文件夾時，觸發 onStartDragOut
        if isDraggingOut && wasInside && !hasDraggedOut {
            hasDraggedOut = true
            onStartDragOut?(app, value.location)
        }
        
        // 如果已經拖出，持續更新位置
        if hasDraggedOut {
            onDragOutContinue?(value.location)
        }
    }
    
    private func handleDragEnd() {
        // 如果已經拖出，通知結束
        if hasDraggedOut {
            onDragOutEnd?()
        }
        
        withAnimation(.spring(response: 0.3)) {
            dragOutOffset = .zero
        }
        draggingApp = nil
        isDraggingOut = false
    }
    
    private var folderNameView: some View {
        Group {
            if isEditingName {
                TextField("Folder Name", text: $folderName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .frame(maxWidth: 200)
                    .onSubmit {
                        isEditingName = false
                        if !folderName.isEmpty {
                            onRename(folderName)
                        }
                    }
                    .onAppear {
                        isNameFieldFocused = true
                    }
            } else {
                Text(folderName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .onTapGesture {
                        isEditingName = true
                    }
            }
        }
    }
}

/// 文件夾內的應用圖標視圖
struct FolderAppIconView: View {
    let app: AppItem
    let isEditing: Bool
    let isDragging: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖示
            Group {
                if let icon = app.appIcon, icon.size.width > 0 {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "app.dashed")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
            }
            .frame(width: GridLayoutManager.iconSize, height: GridLayoutManager.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .opacity(isDragging ? 0.5 : 1.0)
            
            // 名稱
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: GridLayoutManager.labelMaxWidth, height: GridLayoutManager.labelHeight, alignment: .top)
        }
        .wiggle(isEditing && !isDragging)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }
}

// 文件夾內拖放代理
struct FolderDropDelegate: DropDelegate {
    let item: AppItem
    let items: [AppItem]
    @Binding var draggingItem: AppItem?
    let onReorder: (Int, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        onReorder(fromIndex, toIndex)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}



#Preview {
    let sampleApps = (0..<20).map { index in
        AppItem(name: "App \(index + 1)", bundleID: "com.app.\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
    }
    let folder = AppFolder(name: "Utilities", apps: sampleApps)
    
    FolderExpandedView(
        folder: folder,
        onAppTap: { _ in },
        onClose: {},
        onRename: { _ in },
        onReorder: { _, _ in },
        onRemoveApp: { _ in },
        onStartDragOut: { _, _ in }
    )
}
