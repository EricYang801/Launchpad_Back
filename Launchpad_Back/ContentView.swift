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
    
    // 浮動拖曳狀態（用於從文件夾拖出或跨頁拖曳）
    @State private var floatingDragItem: LaunchpadDisplayItem?
    @State private var floatingDragLocation: CGPoint = .zero
    @State private var floatingDragSourcePage: Int = 0
    @State private var floatingDragSourceIndex: Int = 0
    
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
                                    switch item {
                                    case .app(let app):
                                        if !editModeManager.isEditing {
                                            launchpadVM.launchApp(app)
                                        }
                                    case .folder(let folder):
                                        // 編輯模式下也可以進入資料夾
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            expandedFolder = folder
                                        }
                                    }
                                },
                                onLongPress: {
                                    editModeManager.enterEditMode()
                                },
                                onDragChanged: { itemId, location, appIndex in
                                    // location 現在是全局螢幕座標（coordinateSpace: .global）
                                    let screenLocation = location
                                    
                                    // 立即進入浮動拖曳模式
                                    if floatingDragItem == nil {
                                        if let item = filteredItems.first(where: { $0.id == itemId }) {
                                            floatingDragItem = item
                                            floatingDragSourcePage = paginationVM.currentPage
                                            floatingDragSourceIndex = appIndex
                                        }
                                    }
                                    
                                    floatingDragLocation = screenLocation
                                    draggingItemId = itemId
                                    
                                    // 檢測邊緣換頁
                                    _ = checkEdgeForPageChange(screenLocation: screenLocation, geometry: geometry)
                                    
                                    // 計算 drop target
                                    let result = findDropTargetByScreenLocation(at: screenLocation, excludingId: itemId, in: geometry)
                                    dropTargetId = result.targetId
                                    dropTargetIndex = result.targetIndex
                                },
                                onDragEnded: { itemId, appIndex in
                                    handleFloatingDrop()
                                    draggingItemId = nil
                                    dropTargetId = nil
                                    dropTargetIndex = -1
                                    floatingDragItem = nil
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
                            if let updatedFolder = launchpadVM.folders.first(where: { $0.id == folder.id }) {
                                expandedFolder = updatedFolder
                            }
                        },
                        onReorder: { fromIndex, toIndex in
                            launchpadVM.reorderAppsInFolder(folder, from: fromIndex, to: toIndex)
                            if let updatedFolder = launchpadVM.folders.first(where: { $0.id == folder.id }) {
                                expandedFolder = updatedFolder
                            }
                        },
                        onRemoveApp: { app in
                            launchpadVM.removeAppFromFolder(app: app, folder: folder)
                            if let updatedFolder = launchpadVM.folders.first(where: { $0.id == folder.id }) {
                                if updatedFolder.apps.isEmpty {
                                    expandedFolder = nil
                                } else {
                                    expandedFolder = updatedFolder
                                }
                            } else {
                                expandedFolder = nil
                            }
                        },
                        onStartDragOut: { app, screenLocation in
                            // 從文件夾拖出 - 進入浮動拖曳模式
                            floatingDragItem = .app(app)
                            floatingDragLocation = screenLocation
                            floatingDragSourcePage = paginationVM.currentPage
                            floatingDragSourceIndex = -1  // 來自文件夾，沒有 grid index
                            
                            // 從文件夾中移除應用（但不插入到 displayItems，等放置時再決定位置）
                            launchpadVM.removeAppFromFolderOnly(app: app, folder: folder)
                            
                            // 進入編輯模式
                            editModeManager.enterEditMode()
                            
                            // 計算 drop target（初始）
                            // Note: 不關閉文件夾，讓它繼續追蹤拖曳
                        },
                        onDragOutContinue: { screenLocation in
                            // 持續更新浮動拖曳位置
                            floatingDragLocation = screenLocation
                            
                            // 檢測邊緣換頁
                            _ = checkEdgeForPageChange(screenLocation: screenLocation, geometry: geometry)
                            
                            // 計算 drop target
                            if let item = floatingDragItem {
                                let result = findDropTargetByScreenLocation(at: screenLocation, excludingId: item.id, in: geometry)
                                dropTargetId = result.targetId
                                dropTargetIndex = result.targetIndex
                            }
                        },
                        onDragOutEnd: {
                            // 拖曳結束 - 處理放置並關閉文件夾
                            handleFloatingDrop()
                            
                            // 清除狀態
                            draggingItemId = nil
                            dropTargetId = nil
                            dropTargetIndex = -1
                            floatingDragItem = nil
                            
                            // 關閉文件夾
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedFolder = nil
                            }
                        },
                        initialEditingMode: editModeManager.isEditing
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                // 浮動拖曳的 icon（跟著滑鼠）
                if let item = floatingDragItem {
                    floatingDragOverlay(item: item, location: floatingDragLocation, in: geometry)
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
    
    // MARK: - 浮動拖曳視圖
    
    @ViewBuilder
    private func floatingDragOverlay(item: LaunchpadDisplayItem, location: CGPoint, in geometry: GeometryProxy) -> some View {
        ZStack {
            // 顯示放置指示器（藍色）
            if dropTargetIndex >= 0 && dropTargetId == nil {
                screenLocationDropIndicator(at: dropTargetIndex, in: geometry)
            }
            
            // 顯示放置指示器（藍色）
            if dropTargetIndex >= 0 && dropTargetId == nil {
                screenLocationDropIndicator(at: dropTargetIndex, in: geometry)
            }
            
            // 跟隨滑鼠的圖標
            VStack(spacing: 4) {
                switch item {
                case .app(let app):
                    if let icon = app.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.5), radius: 8)
                    }
                    Text(app.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                case .folder(let folder):
                    // 簡化的文件夾圖標（用於拖曳）
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            LazyVGrid(columns: [GridItem(.fixed(16)), GridItem(.fixed(16)), GridItem(.fixed(16))], spacing: 2) {
                                ForEach(folder.apps.prefix(9), id: \.id) { app in
                                    if let icon = app.appIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 14, height: 14)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                            }
                            .padding(4)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 8)
                    Text(folder.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .position(location)
        }
    }
    
    // MARK: - 跨頁拖動支援
    
    // 邊緣檢測狀態
    @State private var edgeScrollTimer: Timer?
    @State private var lastEdgeCheckTime: Date = .distantPast
    @State private var lastEdgeDirection: Int = 0  // -1: 左, 0: 無, 1: 右
    @State private var isWaitingForEdgeExit: Bool = false  // 等待離開邊緣
    
    /// 使用絕對螢幕位置檢測邊緣換頁
    private func checkEdgeForPageChange(screenLocation: CGPoint, geometry: GeometryProxy) -> (pageChanged: Bool, previousPage: Int) {
        let screenWidth = geometry.size.width
        let edgeThreshold: CGFloat = 50
        let previousPage = paginationVM.currentPage
        
        var currentDirection: Int = 0
        
        if screenLocation.x < edgeThreshold {
            currentDirection = -1
        } else if screenLocation.x > screenWidth - edgeThreshold {
            currentDirection = 1
        }
        
        // 如果正在等待離開邊緣
        if isWaitingForEdgeExit {
            if currentDirection == 0 {
                isWaitingForEdgeExit = false
                lastEdgeDirection = 0
            }
            return (false, previousPage)
        }
        
        if currentDirection == 0 {
            lastEdgeDirection = 0
            lastEdgeCheckTime = .distantPast
            return (false, previousPage)
        }
        
        if currentDirection != lastEdgeDirection {
            lastEdgeDirection = currentDirection
            lastEdgeCheckTime = Date()
            return (false, previousPage)
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastEdgeCheckTime) > 0.3 else { return (false, previousPage) }
        
        var pageChanged = false
        
        if currentDirection == -1 && paginationVM.currentPage > 0 {
            isWaitingForEdgeExit = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                paginationVM.previousPage()
            }
            pageChanged = true
            Logger.info("Edge detected: switching to previous page (\(paginationVM.currentPage))")
        }
        else if currentDirection == 1 && paginationVM.currentPage < totalPages - 1 {
            isWaitingForEdgeExit = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                paginationVM.nextPage(totalPages: totalPages)
            }
            pageChanged = true
            Logger.info("Edge detected: switching to next page (\(paginationVM.currentPage))")
        }
        
        return (pageChanged, previousPage)
    }
    
    /// 使用絕對螢幕位置查找 drop target
    private func findDropTargetByScreenLocation(at screenLocation: CGPoint, excludingId: UUID, in geometry: GeometryProxy) -> (targetId: UUID?, targetIndex: Int) {
        let layoutConfig = paginationVM.layoutConfig
        let columns = layoutConfig.columns
        let rows = layoutConfig.rows
        
        let gridWidth = layoutConfig.gridWidth
        let startX = (geometry.size.width - gridWidth) / 2
        
        // 計算 grid 實際高度和起始 Y（考慮垂直置中）
        let itemHeight = GridLayoutManager.itemHeight + GridLayoutManager.verticalSpacing
        let gridHeight = CGFloat(rows) * itemHeight - GridLayoutManager.verticalSpacing
        
        // 頂部區域高度（搜尋欄或編輯模式頭部）約 80
        let topAreaHeight: CGFloat = 80
        // 底部區域高度（頁面指示器）約 60
        let bottomAreaHeight: CGFloat = 60
        // 可用高度
        let availableHeight = geometry.size.height - topAreaHeight - bottomAreaHeight
        // Grid 垂直置中後的起始 Y
        let startY = topAreaHeight + (availableHeight - gridHeight) / 2
        
        let itemWidth = GridLayoutManager.itemWidth + GridLayoutManager.horizontalSpacing
        
        // 計算目標列和行
        let col = Int((screenLocation.x - startX + itemWidth / 2) / itemWidth)
        let row = Int((screenLocation.y - startY + itemHeight / 2) / itemHeight)
        
        guard col >= 0, col < columns, row >= 0 else {
            return (nil, -1)
        }
        
        let targetIndex = row * columns + col
        let pageItems = paginationVM.itemsForPage(filteredItems, page: paginationVM.currentPage)
        
        guard targetIndex >= 0, targetIndex < pageItems.count else {
            // 拖到空白區域，返回末尾位置
            return (nil, min(targetIndex, pageItems.count))
        }
        
        let targetItem = pageItems[targetIndex]
        
        guard targetItem.id != excludingId else {
            return (nil, -1)
        }
        
        // 計算是在圖標中心還是邊緣
        let cellCenterX = startX + CGFloat(col) * itemWidth + itemWidth / 2
        let cellCenterY = startY + CGFloat(row) * itemHeight + GridLayoutManager.iconSize / 2
        
        let distX = abs(screenLocation.x - cellCenterX)
        let distY = abs(screenLocation.y - cellCenterY)
        
        // 如果在圖標中心區域（70% 範圍），視為創建文件夾
        let centerThresholdX = itemWidth * 0.35
        let centerThresholdY = GridLayoutManager.iconSize * 0.35
        
        if distX < centerThresholdX && distY < centerThresholdY {
            Logger.debug("findDropTargetByScreen: found target \(targetItem.name) at index \(targetIndex)")
            return (targetItem.id, targetIndex)
        } else {
            Logger.debug("findDropTargetByScreen: reorder to index \(targetIndex)")
            return (nil, targetIndex)
        }
    }
    
    /// 螢幕位置的放置指示器
    @ViewBuilder
    private func screenLocationDropIndicator(at index: Int, in geometry: GeometryProxy) -> some View {
        let layoutConfig = paginationVM.layoutConfig
        let columns = layoutConfig.columns
        let rows = layoutConfig.rows
        
        let gridWidth = layoutConfig.gridWidth
        let startX = (geometry.size.width - gridWidth) / 2
        
        // 計算 grid 實際高度和起始 Y（考慮垂直置中）
        let itemHeight = GridLayoutManager.itemHeight + GridLayoutManager.verticalSpacing
        let gridHeight = CGFloat(rows) * itemHeight - GridLayoutManager.verticalSpacing
        
        let topAreaHeight: CGFloat = 80
        let bottomAreaHeight: CGFloat = 60
        let availableHeight = geometry.size.height - topAreaHeight - bottomAreaHeight
        let startY = topAreaHeight + (availableHeight - gridHeight) / 2
        
        let itemWidth = GridLayoutManager.itemWidth + GridLayoutManager.horizontalSpacing
        
        let col = index % columns
        let row = index / columns
        
        let x = startX + CGFloat(col) * itemWidth
        let y = startY + CGFloat(row) * itemHeight + GridLayoutManager.itemHeight / 2
        
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.blue)
            .frame(width: 4, height: GridLayoutManager.itemHeight)
            .shadow(color: .blue.opacity(0.5), radius: 4)
            .position(x: x, y: y)
    }
    
    /// 處理浮動拖曳放置
    private func handleFloatingDrop() {
        guard let item = floatingDragItem else { return }
        
        let itemsPerPage = paginationVM.layoutConfig.itemsPerPage
        let pageOffset = paginationVM.currentPage * itemsPerPage
        let sourceGlobalIndex = floatingDragSourcePage * itemsPerPage + floatingDragSourceIndex
        
        // 檢查是否是從 displayItems 中拖出的（不是從文件夾拖出的）
        let isFromGrid = floatingDragSourceIndex >= 0
        
        if let targetId = dropTargetId, let targetItem = filteredItems.first(where: { $0.id == targetId }) {
            // 放到目標上 - 創建文件夾或添加到文件夾
            switch (item, targetItem) {
            case (.app(let draggedApp), .app(let targetApp)):
                if isFromGrid {
                    // 從 grid 拖來的，需要先移除原位置
                    launchpadVM.moveItemToCreateFolder(from: sourceGlobalIndex, targetApp: targetApp, draggedApp: draggedApp)
                } else {
                    _ = launchpadVM.createFolder(app1: targetApp, app2: draggedApp)
                }
                Logger.info("Created folder with \(draggedApp.name) and \(targetApp.name)")
            case (.app(let draggedApp), .folder(let targetFolder)):
                if isFromGrid {
                    launchpadVM.moveItemToFolder(from: sourceGlobalIndex, folder: targetFolder)
                } else {
                    launchpadVM.addAppToFolder(app: draggedApp, folder: targetFolder)
                }
                Logger.info("Added \(draggedApp.name) to folder '\(targetFolder.name)'")
            case (.folder(_), .app(_)):
                // 文件夾拖到應用上 - 只做重新排序
                if isFromGrid && dropTargetIndex >= 0 {
                    let targetGlobalIndex = pageOffset + dropTargetIndex
                    launchpadVM.moveItem(from: sourceGlobalIndex, to: targetGlobalIndex)
                }
            case (.folder(_), .folder(_)):
                // 文件夾拖到文件夾上 - 只做重新排序
                if isFromGrid && dropTargetIndex >= 0 {
                    let targetGlobalIndex = pageOffset + dropTargetIndex
                    launchpadVM.moveItem(from: sourceGlobalIndex, to: targetGlobalIndex)
                }
            }
        } else if dropTargetIndex >= 0 {
            // 放到空位 - 重新排序
            let targetGlobalIndex = pageOffset + dropTargetIndex
            if isFromGrid {
                launchpadVM.moveItem(from: sourceGlobalIndex, to: targetGlobalIndex)
                Logger.info("Moved item from \(sourceGlobalIndex) to \(targetGlobalIndex)")
            } else {
                // 從文件夾拖出來的
                if case .app(let app) = item {
                    launchpadVM.insertAppAt(app: app, index: targetGlobalIndex)
                    Logger.info("Inserted \(app.name) at index \(targetGlobalIndex)")
                }
            }
        } else {
            // 沒有有效目標 - 放到末尾（僅對文件夾拖出的 app 有效）
            if !isFromGrid {
                if case .app(let app) = item {
                    launchpadVM.insertAppAt(app: app, index: launchpadVM.displayItems.count)
                    Logger.info("Inserted \(app.name) at end")
                }
            }
        }
        
        // 清除狀態
        floatingDragItem = nil
        floatingDragLocation = .zero
        dropTargetId = nil
        dropTargetIndex = -1
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
        // 在拖曳過程中，保持原頁面可以接收手勢
        .allowsHitTesting(pageIndex == currentPage || draggingItemId != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }
}

#Preview {
    ContentView()
}
