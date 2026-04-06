//
//  FolderExpandedView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

private struct FolderExpandedLayout {
    let contentFrame: CGRect
    let gridLayout: GridScreenLayout
}

/// 展開的文件夾視圖
struct FolderExpandedView: View {
    let folder: AppFolder
    let onAppTap: (AppItem) -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void
    let onReorder: (Int, Int) -> Void
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
    @State private var hasDraggedOut = false  // 是否已觸發過 dragOut
    @State private var lastReorderTargetIndex: Int?
    @FocusState private var isNameFieldFocused: Bool
    
    private let folderColumns = 4
    
    init(folder: AppFolder, 
         onAppTap: @escaping (AppItem) -> Void, 
         onClose: @escaping () -> Void, 
         onRename: @escaping (String) -> Void,
         onReorder: @escaping (Int, Int) -> Void = { _, _ in },
         onStartDragOut: ((AppItem, CGPoint) -> Void)? = nil,
         onDragOutContinue: ((CGPoint) -> Void)? = nil,
         onDragOutEnd: (() -> Void)? = nil,
         initialEditingMode: Bool = false) {
        self.folder = folder
        self.onAppTap = onAppTap
        self.onClose = onClose
        self.onRename = onRename
        self.onReorder = onReorder
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
    
    private func expandedLayout(in geometry: GeometryProxy) -> FolderExpandedLayout {
        let contentFrame = CGRect(
            x: (geometry.size.width - contentWidth) / 2,
            y: (geometry.size.height - 400) / 2,
            width: contentWidth,
            height: 400
        )
        let gridOrigin = CGPoint(
            x: contentFrame.minX + 24,
            y: contentFrame.minY + (isEditingMode ? 108 : 82)
        )
        let gridLayout = GridScreenLayout(
            frame: CGRect(origin: gridOrigin, size: CGSize(width: contentWidth - 48, height: contentFrame.height)),
            columns: folderColumns,
            itemWidth: GridLayoutManager.itemWidth,
            itemHeight: GridLayoutManager.itemHeight,
            horizontalSpacing: GridLayoutManager.horizontalSpacing,
            verticalSpacing: GridLayoutManager.verticalSpacing
        )

        return FolderExpandedLayout(contentFrame: contentFrame, gridLayout: gridLayout)
    }

    @ViewBuilder
    private func folderContentView(geometry: GeometryProxy) -> some View {
        let layout = expandedLayout(in: geometry)
        
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
            appsGridView(layout: layout)
        }
        .padding(.vertical, 20)
        .frame(width: layout.contentFrame.width)
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
    private func appsGridView(layout: FolderExpandedLayout) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: GridLayoutManager.verticalSpacing) {
                ForEach(Array(folder.apps.enumerated()), id: \.element.id) { index, app in
                    appIconItem(app: app, index: index, layout: layout)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(maxHeight: 400)
    }
    
    @ViewBuilder
    private func appIconItem(app: AppItem, index: Int, layout: FolderExpandedLayout) -> some View {
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
                    handleDragChange(value: value, app: app, appIndex: index, layout: layout)
                }
                .onEnded { _ in
                    handleDragEnd()
                }
        )
    }
    
    private func handleDragChange(value: DragGesture.Value, app: AppItem, appIndex: Int, layout: FolderExpandedLayout) {
        if draggingApp?.id != app.id {
            hasDraggedOut = false
            isDraggingOut = false
            lastReorderTargetIndex = appIndex
        }
        
        draggingApp = app
        dragOutOffset = value.translation

        let wasInside = !isDraggingOut
        isDraggingOut = !layout.contentFrame.contains(value.location)
        
        if !isDraggingOut,
           isEditingMode,
           let currentIndex = folder.apps.firstIndex(where: { $0.id == app.id }),
           let targetIndex = folderIndex(for: value.location, layout: layout),
           targetIndex != currentIndex,
           targetIndex != lastReorderTargetIndex {
            lastReorderTargetIndex = targetIndex
            onReorder(currentIndex, targetIndex)
        }
        
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
        hasDraggedOut = false
        lastReorderTargetIndex = nil
    }
    
    private func folderIndex(for screenLocation: CGPoint, layout: FolderExpandedLayout) -> Int? {
        guard !folder.apps.isEmpty else {
            return nil
        }

        return layout.gridLayout.clampedIndex(
            at: screenLocation,
            itemCount: folder.apps.count,
            allowsTrailingSlot: false
        )
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
            IconImageContainer(isDropTarget: false, isDragging: isDragging) {
                CachedAppIconImage(path: app.path, appName: app.name) {
                    IconLoadingPlaceholder(cornerRadius: 18)
                }
            }

            IconLabelView(name: app.name)
        }
        .wiggle(isEditing && !isDragging)
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }
}

#if DEBUG
struct FolderExpandedView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleApps = (0..<20).map { index in
            AppItem(name: "App \(index + 1)", bundleID: "com.app.\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        let folder = AppFolder(name: "Utilities", apps: sampleApps)
        
        return FolderExpandedView(
            folder: folder,
            onAppTap: { _ in },
            onClose: {},
            onRename: { _ in },
            onReorder: { _, _ in },
            onStartDragOut: { _, _ in }
        )
    }
}
#endif
