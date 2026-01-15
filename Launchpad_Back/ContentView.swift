//
//  ContentView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var launchpadVM = LaunchpadViewModel()
    @StateObject private var searchVM = SearchViewModel()
    @StateObject private var paginationVM = PaginationViewModel()
    @StateObject private var editModeManager = EditModeManager()
    
    var body: some View {
        LaunchpadView()
            .environmentObject(launchpadVM)
            .environmentObject(searchVM)
            .environmentObject(paginationVM)
            .environmentObject(editModeManager)
    }
}

struct LaunchpadView: View {
    @EnvironmentObject var launchpadVM: LaunchpadViewModel
    @EnvironmentObject var searchVM: SearchViewModel
    @EnvironmentObject var paginationVM: PaginationViewModel
    @EnvironmentObject var editModeManager: EditModeManager
    
    @State private var dragAmount = CGSize.zero
    @State private var keyboardManager: KeyboardEventManager?
    @State private var gestureManager: GestureManager?
    @State private var expandedFolder: AppFolder?
    @State private var screenSize: CGSize = .zero
    @State private var draggingItemId: UUID?
    @State private var dropTargetId: UUID?
    @State private var dropTargetIndex: Int = -1
    
    private var filteredItems: [LaunchpadDisplayItem] {
        if searchVM.searchText.isEmpty {
            // 無搜尋時顯示 displayItems（包含文件夾）
            return launchpadVM.displayItems
        } else {
            // 搜尋時只搜尋應用
            let uniqueApps = Dictionary(grouping: launchpadVM.apps, by: \.bundleID)
                .compactMapValues(\.first)
                .values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let filtered = searchVM.filterApps(Array(uniqueApps), by: searchVM.searchText)
            return filtered.map { .app($0) }
        }
    }
    
    private var totalPages: Int {
        paginationVM.totalPages(for: filteredItems.count)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                LaunchpadBackgroundView()
                    .onTapGesture {
                        // 點擊背景退出編輯模式
                        if editModeManager.isEditing {
                            editModeManager.exitEditMode()
                        }
                    }
                
                VStack(spacing: 0) {
                    // 頂部間距
                    Spacer().frame(height: GridLayoutManager.topPadding)
                    
                    // 搜尋欄（編輯模式時隱藏）
                    if !editModeManager.isEditing {
                        SearchBarView(text: $searchVM.searchText)
                            .onChange(of: searchVM.searchText) { _, _ in
                                paginationVM.reset()
                                dragAmount = .zero
                            }
                        
                        Spacer().frame(height: 30)
                    } else {
                        // 編輯模式提示
                        HStack {
                            Text("拖動圖標以重新排列")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Button("完成") {
                                editModeManager.exitEditMode()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.2)))
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        
                        Spacer().frame(height: 30)
                    }
                    
                    // 應用程式網格
                    ZStack {
                        ForEach(0..<totalPages, id: \.self) { pageIndex in
                            PageViewEditable(
                                items: paginationVM.itemsForPage(filteredItems, page: pageIndex),
                                layoutConfig: paginationVM.layoutConfig,
                                pageIndex: pageIndex,
                                currentPage: paginationVM.currentPage,
                                screenWidth: geometry.size.width,
                                dragAmount: editModeManager.isEditing ? .zero : dragAmount,
                                isEditing: editModeManager.isEditing,
                                draggingItemId: draggingItemId,
                                dropTargetId: dropTargetId,
                                onItemTap: { item in
                                    if !editModeManager.isEditing {
                                        switch item {
                                        case .app(let app):
                                            launchpadVM.launchApp(app)
                                        case .folder(let folder):
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                expandedFolder = folder
                                            }
                                        }
                                    }
                                },
                                onLongPress: {
                                    editModeManager.enterEditMode()
                                },
                                onDragChanged: { itemId, location, appIndex in
                                    draggingItemId = itemId
                                    // 查找懸停目標（使用偏移量計算）
                                    let result = findDropTarget(at: location, excludingId: itemId, in: geometry, draggedAppIndex: appIndex)
                                    dropTargetId = result.targetId
                                    dropTargetIndex = result.targetIndex
                                },
                                onDragEnded: { itemId, appIndex in
                                    handleDrop(draggedItemId: itemId, draggedIndex: appIndex)
                                    draggingItemId = nil
                                    dropTargetId = nil
                                    dropTargetIndex = -1
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        editModeManager.isEditing ? nil :
                        DragGesture(minimumDistance: 20)
                            .onChanged { dragAmount = $0.translation }
                            .onEnded(handleDragEnd)
                    )
                    
                    // 頁面指示器
                    if totalPages > 1 && searchVM.searchText.isEmpty {
                        PageIndicatorView(
                            currentPage: paginationVM.currentPage,
                            totalPages: totalPages,
                            onPageTap: { page in
                                paginationVM.jumpToPage(page, totalPages: totalPages)
                                dragAmount = .zero
                            }
                        )
                        .padding(.bottom, GridLayoutManager.bottomPadding - 40)
                    } else {
                        Spacer().frame(height: GridLayoutManager.bottomPadding)
                    }
                }
                
                // 展開的文件夾視圖
                if let folder = expandedFolder {
                    FolderExpandedView(
                        folder: folder,
                        onAppTap: { app in
                            expandedFolder = nil
                            launchpadVM.launchApp(app)
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedFolder = nil
                            }
                        },
                        onRename: { newName in
                            launchpadVM.renameFolder(folder, to: newName)
                        },
                        onReorder: { fromIndex, toIndex in
                            launchpadVM.reorderAppsInFolder(folder, from: fromIndex, to: toIndex)
                            // 更新展開的文件夾以反映變化
                            if let updatedFolder = launchpadVM.folders.first(where: { $0.id == folder.id }) {
                                expandedFolder = updatedFolder
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onAppear {
                screenSize = geometry.size
                paginationVM.updateScreenSize(geometry.size)
                launchpadVM.loadInstalledApps()
                setupEventManagers()
            }
            .onChange(of: geometry.size) { _, newSize in
                screenSize = newSize
                paginationVM.updateScreenSize(newSize)
                paginationVM.validateCurrentPage(totalPages: totalPages)
            }
            .onDisappear {
                teardownEventManagers()
            }
        }
    }
    
    // MARK: - 拖放處理
    
    /// 查找拖放目標，返回目標ID和目標索引
    private func findDropTarget(at location: CGPoint, excludingId: UUID, in geometry: GeometryProxy, draggedAppIndex: Int) -> (targetId: UUID?, targetIndex: Int) {
        let layoutConfig = paginationVM.layoutConfig
        let itemWidth = GridLayoutManager.itemWidth + GridLayoutManager.horizontalSpacing
        let itemHeight = GridLayoutManager.itemHeight + GridLayoutManager.verticalSpacing
        let columns = layoutConfig.columns
        
        let pageItems = paginationVM.itemsForPage(filteredItems, page: paginationVM.currentPage)
        
        // 計算被拖動項目的原始位置
        let draggedCol = draggedAppIndex % columns
        let draggedRow = draggedAppIndex / columns
        
        // location 是相對於被拖動圖標的偏移量，計算目標位置
        // 計算精確的偏移量（以格子為單位）
        let exactColOffset = location.x / itemWidth
        let exactRowOffset = location.y / itemHeight
        
        // 四捨五入到最近的格子
        let colOffset = Int(round(exactColOffset))
        let rowOffset = Int(round(exactRowOffset))
        
        let targetCol = draggedCol + colOffset
        let targetRow = draggedRow + rowOffset
        
        Logger.debug("findDropTarget: offset=(\(location.x), \(location.y)), colOffset=\(colOffset), rowOffset=\(rowOffset)")
        Logger.debug("findDropTarget: dragged(\(draggedCol),\(draggedRow)) -> target(\(targetCol),\(targetRow))")
        
        guard targetCol >= 0, targetCol < columns, targetRow >= 0 else { 
            Logger.debug("findDropTarget: out of grid bounds")
            return (nil, -1) 
        }
        
        let targetIndex = targetRow * columns + targetCol
        
        // 如果目標索引超出當前頁面項目數量，表示拖到空白區域
        guard targetIndex >= 0, targetIndex < pageItems.count else { 
            Logger.debug("findDropTarget: index \(targetIndex) out of range (count: \(pageItems.count)), reorder to end")
            return (nil, min(targetIndex, pageItems.count))
        }
        
        let targetItem = pageItems[targetIndex]
        
        // 不能放到自己身上
        guard targetItem.id != excludingId else { 
            Logger.debug("findDropTarget: same as dragging item")
            return (nil, -1) 
        }
        
        // 計算拖動位置相對於目標格子中心的偏移
        // 如果偏移量較小（即位置接近原始格子），則視為重新排序
        // 如果偏移量較大（即明確移動到另一個格子上），則視為創建文件夾
        
        // 計算偏移在當前格子內的精確位置（-0.5 ~ 0.5 的範圍，0 表示格子中心）
        let fractionalCol = exactColOffset - Double(colOffset)
        let fractionalRow = exactRowOffset - Double(rowOffset)
        
        // 定義閾值：如果在格子中心 70% 的區域內，視為創建文件夾
        let centerThreshold = 0.35
        let isInIconCenter = abs(fractionalCol) < centerThreshold && abs(fractionalRow) < centerThreshold
        
        Logger.debug("findDropTarget: fractional=(\(fractionalCol), \(fractionalRow)), isInCenter=\(isInIconCenter)")
        
        if isInIconCenter {
            // 在圖標中心區域，視為創建文件夾
            Logger.info("findDropTarget: found target \(targetItem.name) at index \(targetIndex) (in icon center)")
            return (targetItem.id, targetIndex)
        } else {
            // 在邊緣區域，視為重新排序
            Logger.info("findDropTarget: reorder to index \(targetIndex) (near edge)")
            return (nil, targetIndex)
        }
    }
    
    private func handleDrop(draggedItemId: UUID, draggedIndex: Int) {
        Logger.info("handleDrop called: draggedId=\(draggedItemId), targetId=\(String(describing: dropTargetId)), targetIndex=\(dropTargetIndex)")
        
        // 如果有目標項目，嘗試創建文件夾或添加到文件夾
        if let targetId = dropTargetId {
            // 找到被拖拽的項目和目標項目
            guard let draggedItem = filteredItems.first(where: { $0.id == draggedItemId }),
                  let targetItem = filteredItems.first(where: { $0.id == targetId }) else {
                Logger.error("handleDrop: could not find items")
                return
            }
            
            // 只有兩個都是應用時才能創建文件夾
            switch (draggedItem, targetItem) {
            case (.app(let draggedApp), .app(let targetApp)):
                // 創建新文件夾
                let folder = launchpadVM.createFolder(app1: targetApp, app2: draggedApp)
                Logger.info("Created folder '\(folder.name)' with \(draggedApp.name) and \(targetApp.name)")
            case (.app(let draggedApp), .folder(let targetFolder)):
                // 將應用拖入現有文件夾
                launchpadVM.addAppToFolder(app: draggedApp, folder: targetFolder)
                Logger.info("Added \(draggedApp.name) to folder '\(targetFolder.name)'")
            default:
                Logger.info("handleDrop: invalid drop combination")
            }
        } else if dropTargetIndex >= 0 && dropTargetIndex != draggedIndex {
            // 沒有目標項目但有目標位置，進行重新排序
            let itemsPerPage = paginationVM.layoutConfig.columns * paginationVM.layoutConfig.rows
            let pageOffset = paginationVM.currentPage * itemsPerPage
            let sourceIndex = pageOffset + draggedIndex
            let destinationIndex = pageOffset + dropTargetIndex
            
            Logger.info("handleDrop: reordering from \(sourceIndex) to \(destinationIndex)")
            launchpadVM.moveItem(from: sourceIndex, to: destinationIndex)
        } else {
            Logger.info("handleDrop: no valid drop target")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupEventManagers() {
        keyboardManager = KeyboardEventManager(
            onLeftArrow: { paginationVM.previousPage() },
            onRightArrow: { paginationVM.nextPage(totalPages: totalPages) },
            onEscape: handleEscapeKey,
            onCommandW: hideWindow,
            onCommandQ: quitApp
        )
        keyboardManager?.startListening()
        
        gestureManager = GestureManager { [weak paginationVM, weak launchpadVM, weak searchVM] direction in
            guard let paginationVM = paginationVM,
                  let launchpadVM = launchpadVM,
                  let searchVM = searchVM else { return }
            
            let uniqueApps = Dictionary(grouping: launchpadVM.apps, by: \.bundleID)
                .compactMapValues(\.first)
                .values
            let filteredCount = searchVM.filterApps(Array(uniqueApps), by: searchVM.searchText).count
            let totalPages = paginationVM.totalPages(for: filteredCount)
            
            Logger.debug("Page change requested: direction=\(direction), currentPage=\(paginationVM.currentPage), totalPages=\(totalPages)")
            
            DispatchQueue.main.async {
                if direction > 0 {
                    paginationVM.nextPage(totalPages: totalPages)
                } else {
                    paginationVM.previousPage()
                }
            }
        }
        gestureManager?.startListening()
    }
    
    private func teardownEventManagers() {
        keyboardManager?.stopListening()
        gestureManager?.stopListening()
        keyboardManager = nil
        gestureManager = nil
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 50
        let velocity = value.predictedEndLocation.x - value.location.x
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if value.translation.width > threshold || velocity > 200 {
                paginationVM.previousPage()
            } else if value.translation.width < -threshold || velocity < -200 {
                paginationVM.nextPage(totalPages: totalPages)
            }
            dragAmount = .zero
        }
    }
    
    private func handleEscapeKey() {
        if editModeManager.isEditing {
            editModeManager.exitEditMode()
        } else if expandedFolder != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expandedFolder = nil
            }
        } else if !searchVM.searchText.isEmpty {
            searchVM.clearSearch()
        } else {
            hideWindow()
        }
    }
    
    private func hideWindow() {
        NSApplication.shared.keyWindow?.orderOut(nil)
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - 可編輯的頁面視圖

struct PageViewEditable: View {
    let items: [LaunchpadDisplayItem]
    let layoutConfig: GridLayoutConfig
    let pageIndex: Int
    let currentPage: Int
    let screenWidth: CGFloat
    let dragAmount: CGSize
    let isEditing: Bool
    let draggingItemId: UUID?
    let dropTargetId: UUID?
    let onItemTap: (LaunchpadDisplayItem) -> Void
    let onLongPress: () -> Void
    let onDragChanged: (UUID, CGPoint, Int) -> Void
    let onDragEnded: (UUID, Int) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            LazyVGrid(columns: layoutConfig.gridColumns, spacing: GridLayoutManager.verticalSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    LaunchpadItemView(
                        item: item,
                        onAppTap: { app in onItemTap(.app(app)) },
                        onFolderTap: { folder in onItemTap(.folder(folder)) },
                        isDragging: draggingItemId == item.id,
                        isEditing: isEditing,
                        isDropTarget: dropTargetId == item.id,
                        onLongPress: onLongPress,
                        onDragChanged: { location in
                            onDragChanged(item.id, location, index)
                        },
                        onDragEnded: {
                            onDragEnded(item.id, index)
                        }
                    )
                }
            }
            .frame(width: layoutConfig.gridWidth)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(
            x: CGFloat(pageIndex - currentPage) * screenWidth + dragAmount.width,
            y: 0
        )
        .opacity(pageIndex == currentPage ? 1.0 : 0.6)
        .scaleEffect(pageIndex == currentPage ? 1.0 : 0.92)
        .allowsHitTesting(pageIndex == currentPage)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }
}

#Preview {
    ContentView()
}
