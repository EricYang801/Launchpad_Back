//
//  ContentView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import AppKit

private struct FloatingDragState {
    var draggingItemId: UUID?
    var item: LaunchpadDisplayItem?
    var location: CGPoint = .zero
    var startedInGrid = false
    var dropTargetId: UUID?
    var dropTargetIndex: Int = -1

    mutating func clear() {
        draggingItemId = nil
        item = nil
        location = .zero
        startedInGrid = false
        dropTargetId = nil
        dropTargetIndex = -1
    }
}

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
    @State private var showingResetConfirmation = false
    @State private var floatingDragState = FloatingDragState()
    
    private var filteredItems: [LaunchpadDisplayItem] {
        launchpadVM.filteredDisplayItems(matching: searchVM.searchText)
    }
    
    private var totalPages: Int {
        paginationVM.totalPages(for: filteredItems.count)
    }

    private var renderedPageIndices: [Int] {
        guard totalPages > 0 else { return [] }
        
        let lowerBound = max(0, paginationVM.currentPage - 1)
        let upperBound = min(totalPages - 1, paginationVM.currentPage + 1)
        return Array(lowerBound...upperBound)
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
                    Spacer().frame(height: 6)
                    
                    // 搜尋欄（編輯模式時隱藏）
                    if !editModeManager.isEditing {
                        normalHeaderView
                        
                        Spacer().frame(height: 4)
                    } else {
                        editingHeaderView
                        
                        Spacer().frame(height: 4)
                    }
                    
                    // 應用程式網格
                    ZStack {
                        ForEach(renderedPageIndices, id: \.self) { pageIndex in
                            PageViewEditable(
                                items: paginationVM.itemsForPage(filteredItems, page: pageIndex),
                                layoutConfig: paginationVM.layoutConfig,
                                pageIndex: pageIndex,
                                currentPage: paginationVM.currentPage,
                                screenWidth: geometry.size.width,
                                dragAmount: editModeManager.isEditing ? .zero : dragAmount,
                                isEditing: editModeManager.isEditing,
                                draggingItemId: floatingDragState.draggingItemId,
                                dropTargetId: floatingDragState.dropTargetId,
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
                                onDragChanged: { itemId, location in
                                    if floatingDragState.item == nil,
                                       let item = filteredItems.first(where: { $0.id == itemId }) {
                                        floatingDragState.item = item
                                        floatingDragState.startedInGrid = true
                                    }

                                    floatingDragState.location = location
                                    floatingDragState.draggingItemId = itemId

                                    _ = checkEdgeForPageChange(screenLocation: location, geometry: geometry)

                                    let result = findDropTargetByScreenLocation(at: location, excludingId: itemId, in: geometry)
                                    floatingDragState.dropTargetId = result.targetId
                                    floatingDragState.dropTargetIndex = result.targetIndex
                                },
                                onDragEnded: { _ in
                                    handleFloatingDrop()
                                    floatingDragState.clear()
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
                        .padding(.bottom, 6)
                    } else {
                        Spacer().frame(height: 6)
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
                        onStartDragOut: { app, screenLocation in
                            floatingDragState.item = .app(app)
                            floatingDragState.location = screenLocation
                            floatingDragState.startedInGrid = false

                            launchpadVM.removeAppFromFolder(app: app, folder: folder, placement: .floatingDrag)
                            editModeManager.enterEditMode()
                        },
                        onDragOutContinue: { screenLocation in
                            floatingDragState.location = screenLocation
                            _ = checkEdgeForPageChange(screenLocation: screenLocation, geometry: geometry)

                            if let item = floatingDragState.item {
                                let result = findDropTargetByScreenLocation(at: screenLocation, excludingId: item.id, in: geometry)
                                floatingDragState.dropTargetId = result.targetId
                                floatingDragState.dropTargetIndex = result.targetIndex
                            }
                        },
                        onDragOutEnd: {
                            handleFloatingDrop()
                            floatingDragState.clear()

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedFolder = nil
                            }
                        },
                        initialEditingMode: editModeManager.isEditing
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                // 浮動拖曳的 icon（跟著滑鼠）
                if let item = floatingDragState.item {
                    floatingDragOverlay(item: item, location: floatingDragState.location, in: geometry)
                }
            }
            .alert("重設版面？", isPresented: $showingResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("重設", role: .destructive) {
                    resetLayout()
                }
            } message: {
                Text("這會清除自訂排序與所有資料夾，並恢復成依名稱排序。")
            }
            .onAppear {
                paginationVM.updateScreenSize(geometry.size)
                launchpadVM.loadInstalledApps()
                launchpadVM.updateActivePage(paginationVM.currentPage, itemsPerPage: paginationVM.appsPerPage)
                setupEventManagers()
            }
            .onChange(of: geometry.size) { _, newSize in
                paginationVM.updateScreenSize(newSize)
                paginationVM.validateCurrentPage(totalPages: totalPages)
                launchpadVM.updateActivePage(paginationVM.currentPage, itemsPerPage: paginationVM.appsPerPage)
            }
            .onChange(of: paginationVM.currentPage) { _, newPage in
                launchpadVM.updateActivePage(newPage, itemsPerPage: paginationVM.appsPerPage)
            }
            .onChange(of: totalPages) { _, _ in
                paginationVM.validateCurrentPage(totalPages: totalPages)
                launchpadVM.updateActivePage(paginationVM.currentPage, itemsPerPage: paginationVM.appsPerPage)
            }
            .onDisappear {
                teardownEventManagers()
            }
        }
    }

    private var normalHeaderView: some View {
        SearchBarView(text: $searchVM.searchText)
            .onChange(of: searchVM.searchText) { _, _ in
                paginationVM.reset()
                dragAmount = .zero
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                resetLayoutButton
                    .padding(.trailing, 40)
            }
    }

    private var editingHeaderView: some View {
        HStack {
            Text("拖動圖標以重新排列")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            resetLayoutButton
            
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
        .padding(.top, 5)
    }

    private var resetLayoutButton: some View {
        Button {
            showingResetConfirmation = true
        } label: {
            Label("重設版面", systemImage: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .disabled(launchpadVM.isLoading || launchpadVM.apps.isEmpty)
        .opacity((launchpadVM.isLoading || launchpadVM.apps.isEmpty) ? 0.5 : 1)
    }
    
    // MARK: - 浮動拖曳視圖
    
    @ViewBuilder
    private func floatingDragOverlay(item: LaunchpadDisplayItem, location: CGPoint, in geometry: GeometryProxy) -> some View {
        ZStack {
            // 顯示放置指示器（藍色）
            if floatingDragState.dropTargetIndex >= 0 && floatingDragState.dropTargetId == nil {
                screenLocationDropIndicator(at: floatingDragState.dropTargetIndex, in: geometry)
            }
            
            // 跟隨滑鼠的圖標
            VStack(spacing: 4) {
                switch item {
                case .app(let app):
                    CachedAppIconImage(path: app.path, appName: app.name) {
                        IconLoadingPlaceholder(cornerRadius: 14)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.5), radius: 8)
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
                                    CachedAppIconImage(path: app.path, appName: app.name) {
                                        IconLoadingPlaceholder(cornerRadius: 3)
                                    }
                                    .frame(width: 14, height: 14)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
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
    @State private var lastEdgeCheckTime: Date = .distantPast
    @State private var lastEdgeDirection: Int = 0  // -1: 左, 0: 無, 1: 右
    @State private var isWaitingForEdgeExit: Bool = false  // 等待離開邊緣

    private func currentGridLayout(in geometry: GeometryProxy) -> GridScreenLayout {
        let layoutConfig = paginationVM.layoutConfig
        let topAreaHeight = GridLayoutManager.headerAreaHeight
        let bottomAreaHeight = GridLayoutManager.footerAreaHeight
        let availableHeight = geometry.size.height - topAreaHeight - bottomAreaHeight
        let origin = CGPoint(
            x: (geometry.size.width - layoutConfig.gridWidth) / 2,
            y: topAreaHeight + (availableHeight - layoutConfig.gridHeight) / 2
        )

        return GridScreenLayout(
            frame: CGRect(origin: origin, size: CGSize(width: layoutConfig.gridWidth, height: layoutConfig.gridHeight)),
            columns: layoutConfig.columns,
            itemWidth: GridLayoutManager.itemWidth,
            itemHeight: GridLayoutManager.itemHeight,
            horizontalSpacing: GridLayoutManager.horizontalSpacing,
            verticalSpacing: GridLayoutManager.verticalSpacing
        )
    }
    
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
        let gridLayout = currentGridLayout(in: geometry)
        let pageItems = paginationVM.itemsForPage(filteredItems, page: paginationVM.currentPage)

        guard let targetIndex = gridLayout.clampedIndex(
            at: screenLocation,
            itemCount: pageItems.count,
            allowsTrailingSlot: true
        ) else {
            return (nil, -1)
        }

        guard targetIndex < pageItems.count else {
            return (nil, targetIndex)
        }

        let targetItem = pageItems[targetIndex]
        guard targetItem.id != excludingId else {
            return (nil, -1)
        }

        if gridLayout.isNearItemCenter(
            at: screenLocation,
            index: targetIndex,
            horizontalRatio: 0.35,
            verticalRatio: 0.35,
            visualHeight: GridLayoutManager.iconSize
        ) {
            Logger.debug("findDropTargetByScreen: found target \(targetItem.name) at index \(targetIndex)")
            return (targetItem.id, targetIndex)
        }

        Logger.debug("findDropTargetByScreen: reorder to index \(targetIndex)")
        return (nil, targetIndex)
    }
    
    /// 螢幕位置的放置指示器
    @ViewBuilder
    private func screenLocationDropIndicator(at index: Int, in geometry: GeometryProxy) -> some View {
        let position = currentGridLayout(in: geometry).leadingIndicatorPosition(at: index)
        
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.blue)
            .frame(width: 4, height: GridLayoutManager.itemHeight)
            .shadow(color: .blue.opacity(0.5), radius: 4)
            .position(x: position.x, y: position.y)
    }
    
    /// 處理浮動拖曳放置
    private func handleFloatingDrop() {
        guard let item = floatingDragState.item else { return }
        
        let itemsPerPage = paginationVM.layoutConfig.itemsPerPage
        let pageOffset = paginationVM.currentPage * itemsPerPage
        let isFromGrid = floatingDragState.startedInGrid
        
        if let targetId = floatingDragState.dropTargetId,
           let targetItem = filteredItems.first(where: { $0.id == targetId }) {
            // 放到目標上 - 創建文件夾或添加到文件夾
            switch (item, targetItem) {
            case (.app(let draggedApp), .app(let targetApp)):
                _ = launchpadVM.createFolder(app1: targetApp, app2: draggedApp)
                Logger.info("Created folder with \(draggedApp.name) and \(targetApp.name)")
            case (.app(let draggedApp), .folder(let targetFolder)):
                launchpadVM.addAppToFolder(app: draggedApp, folder: targetFolder)
                Logger.info("Added \(draggedApp.name) to folder '\(targetFolder.name)'")
            case (.folder(_), .app(_)):
                // 文件夾拖到應用上 - 只做重新排序
                if isFromGrid && floatingDragState.dropTargetIndex >= 0 {
                    let targetGlobalIndex = pageOffset + floatingDragState.dropTargetIndex
                    launchpadVM.moveItem(withId: item.id, to: targetGlobalIndex)
                }
            case (.folder(_), .folder(_)):
                // 文件夾拖到文件夾上 - 只做重新排序
                if isFromGrid && floatingDragState.dropTargetIndex >= 0 {
                    let targetGlobalIndex = pageOffset + floatingDragState.dropTargetIndex
                    launchpadVM.moveItem(withId: item.id, to: targetGlobalIndex)
                }
            }
        } else if floatingDragState.dropTargetIndex >= 0 {
            // 放到空位 - 重新排序
            let targetGlobalIndex = pageOffset + floatingDragState.dropTargetIndex
            if isFromGrid {
                launchpadVM.moveItem(withId: item.id, to: targetGlobalIndex)
                Logger.info("Moved item \(item.id) to \(targetGlobalIndex)")
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

        floatingDragState.clear()
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
            
            let filteredCount = launchpadVM.filteredDisplayItems(matching: searchVM.searchText).count
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
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.hideMainWindow()
        } else {
            NSApplication.shared.keyWindow?.orderOut(nil)
        }
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func resetLayout() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            expandedFolder = nil
        }
        clearFloatingDragState()
        dragAmount = .zero
        searchVM.clearSearch()
        paginationVM.reset()
        editModeManager.exitEditMode()
        launchpadVM.resetLayout()
    }

    private func clearFloatingDragState() {
        floatingDragState.clear()
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
    let onDragChanged: (UUID, CGPoint) -> Void
    let onDragEnded: (UUID) -> Void
    
    var body: some View {
        VStack {
            // 減少頂部空間，讓 grid 更靠近搜尋欄
            Spacer().frame(minHeight: 0, maxHeight: 10)
            
            LazyVGrid(columns: layoutConfig.gridColumns, spacing: GridLayoutManager.verticalSpacing) {
                ForEach(items, id: \.id) { item in
                    LaunchpadItemView(
                        item: item,
                        onAppTap: { app in onItemTap(.app(app)) },
                        onFolderTap: { folder in onItemTap(.folder(folder)) },
                        isDragging: draggingItemId == item.id,
                        isEditing: isEditing,
                        isDropTarget: dropTargetId == item.id,
                        onLongPress: onLongPress,
                        onDragChanged: { location in
                            onDragChanged(item.id, location)
                        },
                        onDragEnded: {
                            onDragEnded(item.id)
                        }
                    )
                }
            }
            .frame(width: layoutConfig.gridWidth)
            
            // 減少底部空間
            Spacer().frame(minHeight: 0, maxHeight: 5)
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

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
