//
//  LaunchpadViewModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//  Optimized for memory usage on 2025/1/16
//

import SwiftUI
import Combine

/// 主要的 Launchpad ViewModel
/// 負責應用程式列表的管理和狀態
/// 
/// 記憶體優化：
/// - 使用防抖動機制減少頻繁的 UserDefaults 寫入
/// - 優化 @Published 屬性使用
/// - 改善記憶體釋放邏輯
class LaunchpadViewModel: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var folders: [AppFolder] = []
    @Published var displayItems: [LaunchpadDisplayItem] = [] {
        didSet {
            // 使用防抖動，避免頻繁保存
            scheduleSave()
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let scannerService: AppScannerService
    private let launcherService: AppLauncherService
    private var cancellables: Set<AnyCancellable> = []
    
    // 持久化存儲鍵
    private let orderKey = "launchpad_item_order"
    private let foldersKey = "launchpad_folders"
    
    // 優化：防抖動計時器，減少頻繁的 UserDefaults 寫入
    private var saveOrderWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5
    
    // 優化：快取當前頁面信息，用於圖標快取管理
    private var currentPage: Int = 0
    private let itemsPerPage: Int = 35
    
    init(
        scannerService: AppScannerService = AppScannerService(),
        launcherService: AppLauncherService = AppLauncherService()
    ) {
        self.scannerService = scannerService
        self.launcherService = launcherService
        Logger.info("LaunchpadViewModel initialized with memory optimizations")
    }
    
    deinit {
        // 確保保存待處理的更改
        saveOrderWorkItem?.cancel()
        saveOrderImmediately()
        Logger.debug("LaunchpadViewModel deinitialized")
    }
    
    /// 加載已安裝的應用程式
    func loadInstalledApps() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        Logger.info("Starting app loading...")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                let apps = self?.scannerService.scanInstalledApps() ?? []
                
                DispatchQueue.main.async {
                    self?.apps = apps
                    self?.initializeDisplayItems()
                    self?.isLoading = false
                    Logger.info("App loading completed. Found \(apps.count) applications")
                    
                    // 優化：更新圖標快取的活躍頁面
                    self?.updateIconCacheActivePage()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Failed to load apps: \(error.localizedDescription)"
                    Logger.error(error)
                }
            }
        }
    }
    
    /// 更新顯示項目列表（移除已在文件夾中的應用，並同步文件夾內容）
    private func updateDisplayItems() {
        // 獲取所有在文件夾中的應用 bundleID
        let appsInFolders = Set(folders.flatMap { $0.apps.map { $0.bundleID } })
        
        // 更新 displayItems：移除已在文件夾中的應用，並同步文件夾內容
        displayItems = displayItems.compactMap { item -> LaunchpadDisplayItem? in
            switch item {
            case .app(let app):
                // 如果應用已在文件夾中，則移除
                return appsInFolders.contains(app.bundleID) ? nil : item
            case .folder(let oldFolder):
                // 用最新的文件夾數據替換（同步 apps 等內容）
                if let updatedFolder = folders.first(where: { $0.id == oldFolder.id }) {
                    return .folder(updatedFolder)
                }
                // 文件夾已被刪除
                return nil
            }
        }
        
        // 注意：這裡不直接調用 saveOrder()，因為 didSet 會觸發防抖動保存
    }
    
    /// 初始化顯示項目列表（首次載入時按名稱排序，或從保存的順序載入）
    private func initializeDisplayItems() {
        // 嘗試載入保存的文件夾
        loadFolders()
        
        // 獲取所有在文件夾中的應用 ID
        let appsInFolders = Set(folders.flatMap { $0.apps.map { $0.bundleID } })
        
        // 嘗試載入保存的順序
        if let savedOrder = loadOrder() {
            var orderedItems: [LaunchpadDisplayItem] = []
            
            // 按保存的順序排列
            for itemKey in savedOrder {
                // 檢查是否為文件夾 (格式: "folder:UUID")
                if itemKey.hasPrefix("folder:") {
                    let folderId = String(itemKey.dropFirst(7))
                    if let folder = folders.first(where: { $0.id.uuidString == folderId }) {
                        orderedItems.append(.folder(folder))
                    }
                }
                // 檢查是否為應用 (格式: "app:bundleID")
                else if itemKey.hasPrefix("app:") {
                    let bundleId = String(itemKey.dropFirst(4))
                    if let app = apps.first(where: { $0.bundleID == bundleId && !appsInFolders.contains($0.bundleID) }) {
                        orderedItems.append(.app(app))
                    }
                }
            }
            
            // 添加新安裝的應用（不在保存順序中的）
            let existingBundleIds = Set(orderedItems.compactMap { item -> String? in
                if case .app(let app) = item { return app.bundleID }
                return nil
            })
            let newApps = apps.filter { !appsInFolders.contains($0.bundleID) && !existingBundleIds.contains($0.bundleID) }
            orderedItems.append(contentsOf: newApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { .app($0) })
            
            displayItems = orderedItems
            Logger.info("Loaded saved order with \(orderedItems.count) items")
        } else {
            // 沒有保存的順序，按名稱排序
            var items: [LaunchpadDisplayItem] = []
            
            // 添加不在文件夾中的應用
            let standaloneApps = apps.filter { !appsInFolders.contains($0.bundleID) }
            items.append(contentsOf: standaloneApps.map { .app($0) })
            
            // 添加文件夾
            items.append(contentsOf: folders.map { .folder($0) })
            
            // 按名稱排序
            displayItems = items.sorted { item1, item2 in
                item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
            Logger.info("No saved order, sorted by name")
        }
    }
    
    // MARK: - 持久化（優化版）
    
    /// 排程保存（使用防抖動）
    private func scheduleSave() {
        saveOrderWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveOrderImmediately()
        }
        
        saveOrderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }
    
    /// 立即保存當前順序（內部方法）
    private func saveOrderImmediately() {
        // 使用 bundleID（對於應用）或 folder ID（對於文件夾）來保存順序
        let order = displayItems.map { item -> String in
            switch item {
            case .app(let app):
                return "app:\(app.bundleID)"
            case .folder(let folder):
                return "folder:\(folder.id.uuidString)"
            }
        }
        
        // 優化：批次寫入，減少 I/O 操作
        let defaults = UserDefaults.standard
        defaults.set(order, forKey: orderKey)
        saveFolders(to: defaults)
        defaults.synchronize()  // 強制立即寫入
        
        Logger.debug("Saved order with \(order.count) items and \(folders.count) folders")
    }
    
    /// 保存當前順序（公開方法，用於需要立即保存的場景）
    func saveOrder() {
        saveOrderImmediately()
    }
    
    /// 載入保存的順序
    private func loadOrder() -> [String]? {
        return UserDefaults.standard.stringArray(forKey: orderKey)
    }
    
    /// 保存文件夾（優化：接受 UserDefaults 參數，避免重複獲取）
    private func saveFolders(to defaults: UserDefaults? = nil) {
        let defaults = defaults ?? UserDefaults.standard
        let folderData = folders.map { folder -> [String: Any] in
            return [
                "id": folder.id.uuidString,
                "name": folder.name,
                "appBundleIds": folder.apps.map { $0.bundleID }  // 使用 bundleID
            ]
        }
        defaults.set(folderData, forKey: foldersKey)
    }
    
    /// 載入文件夾
    private func loadFolders() {
        guard let folderData = UserDefaults.standard.array(forKey: foldersKey) as? [[String: Any]] else {
            return
        }
        
        folders = folderData.compactMap { data -> AppFolder? in
            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = data["name"] as? String else {
                return nil
            }
            
            // 支援舊格式 (appIds) 和新格式 (appBundleIds)
            let folderApps: [AppItem]
            if let bundleIds = data["appBundleIds"] as? [String] {
                // 新格式：使用 bundleID
                folderApps = bundleIds.compactMap { bundleId -> AppItem? in
                    return apps.first { $0.bundleID == bundleId }
                }
            } else if let appIds = data["appIds"] as? [String] {
                // 舊格式：使用 UUID（相容性）
                folderApps = appIds.compactMap { appIdString -> AppItem? in
                    guard let appId = UUID(uuidString: appIdString) else { return nil }
                    return apps.first { $0.id == appId }
                }
            } else {
                return nil
            }
            
            guard !folderApps.isEmpty else { return nil }
            
            return AppFolder(id: id, name: name, apps: folderApps)
        }
        
        Logger.info("Loaded \(folders.count) folders")
    }
    
    // MARK: - 圖標快取優化
    
    /// 更新圖標快取的活躍頁面
    /// - Parameter page: 當前頁面索引
    func updateActivePage(_ page: Int) {
        currentPage = page
        updateIconCacheActivePage()
        
        // 預載入相鄰頁面的圖標
        preloadAdjacentPageIcons(page)
    }
    
    /// 更新圖標快取管理器的活躍頁面信息
    private func updateIconCacheActivePage() {
        AppIconCache.shared.updateActivePage(currentPage, itemsPerPage: itemsPerPage)
    }
    
    /// 預載入相鄰頁面的圖標
    private func preloadAdjacentPageIcons(_ page: Int) {
        let startIndex = max(0, (page - 1) * itemsPerPage)
        let endIndex = min(displayItems.count, (page + 2) * itemsPerPage)
        
        let paths = displayItems[startIndex..<endIndex].compactMap { item -> String? in
            if case .app(let app) = item {
                return app.path
            }
            return nil
        }
        
        AppIconCache.shared.preloadIcons(for: paths)
    }
    
    // MARK: - 應用程式操作
    
    /// 啟動應用程式
    /// - Parameter app: 要啟動的應用程式
    func launchApp(_ app: AppItem) {
        Logger.info("Launching app: \(app.name)")
        
        launcherService.launchAsync(app) { [weak self] success in
            if success {
                Logger.info("Successfully launched: \(app.name)")
            } else {
                let errorMsg = "Failed to launch: \(app.name)"
                Logger.error(errorMsg)
                self?.errorMessage = errorMsg
            }
        }
    }
    
    /// 刷新應用程式列表
    func refreshApps() {
        Logger.info("Refreshing app list...")
        apps.removeAll()
        AppIconCache.shared.clearCache()
        loadInstalledApps()
    }
    
    /// 清除錯誤訊息
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - 排序和文件夾管理
    
    /// 移動項目到新位置
    func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < displayItems.count,
              destinationIndex >= 0, destinationIndex <= displayItems.count else {
            Logger.debug("moveItem: invalid indices source=\(sourceIndex), dest=\(destinationIndex), count=\(displayItems.count)")
            return
        }
        
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let item = displayItems.remove(at: sourceIndex)
            displayItems.insert(item, at: min(adjustedDestination, displayItems.count))
        }
        
        Logger.info("Moved item from \(sourceIndex) to \(adjustedDestination)")
    }
    
    /// 創建新文件夾（將兩個應用合併，在目標位置插入文件夾）
    @discardableResult
    func createFolder(app1: AppItem, app2: AppItem) -> AppFolder {
        let folder = AppFolder(
            name: "New Folder",
            apps: [app1, app2]
        )
        
        folders.append(folder)
        
        // 找到 app1（目標應用）在 displayItems 中的位置
        if let targetIndex = displayItems.firstIndex(where: { 
            if case .app(let app) = $0 { return app.id == app1.id }
            return false
        }) {
            // 在目標位置插入文件夾
            displayItems[targetIndex] = .folder(folder)
            
            // 移除被拖拽的應用（app2）
            displayItems.removeAll { item in
                if case .app(let app) = item { return app.id == app2.id }
                return false
            }
        } else {
            // 如果找不到，回退到舊行為
            updateDisplayItems()
        }
        
        Logger.info("Created folder '\(folder.name)' with apps: \(app1.name), \(app2.name)")
        return folder
    }
    
    /// 移動項目並創建文件夾
    func moveItemToCreateFolder(from sourceIndex: Int, targetApp: AppItem, draggedApp: AppItem) {
        guard sourceIndex >= 0, sourceIndex < displayItems.count else { return }
        
        // 先移除源位置的項目
        displayItems.remove(at: sourceIndex)
        
        // 創建文件夾
        let folder = AppFolder(name: "New Folder", apps: [targetApp, draggedApp])
        folders.append(folder)
        
        // 找到目標應用的位置並替換為文件夾
        if let targetIndex = displayItems.firstIndex(where: {
            if case .app(let app) = $0 { return app.id == targetApp.id }
            return false
        }) {
            displayItems[targetIndex] = .folder(folder)
        }
        
        Logger.info("Created folder with \(targetApp.name) and \(draggedApp.name)")
    }
    
    /// 移動項目到文件夾
    func moveItemToFolder(from sourceIndex: Int, folder: AppFolder) {
        guard sourceIndex >= 0, sourceIndex < displayItems.count else { return }
        
        // 獲取要移動的項目
        let item = displayItems[sourceIndex]
        guard case .app(let app) = item else { return }
        
        // 添加到文件夾
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        
        var updatedFolder = folders[folderIndex]
        guard !updatedFolder.apps.contains(where: { $0.id == app.id }) else { return }
        
        updatedFolder.apps.append(app)
        folders[folderIndex] = updatedFolder
        
        // 從 displayItems 移除
        displayItems.remove(at: sourceIndex)
        
        // 更新 displayItems 中的文件夾
        if let folderDisplayIndex = displayItems.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folder.id }
            return false
        }) {
            displayItems[folderDisplayIndex] = .folder(updatedFolder)
        }
        
        Logger.info("Moved \(app.name) to folder '\(folder.name)'")
    }
    
    /// 將應用添加到現有文件夾
    func addAppToFolder(app: AppItem, folder: AppFolder) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        
        var updatedFolder = folders[folderIndex]
        
        // 檢查應用是否已在文件夾中
        guard !updatedFolder.apps.contains(where: { $0.id == app.id }) else {
            return
        }
        
        updatedFolder.apps.append(app)
        folders[folderIndex] = updatedFolder
        updateDisplayItems()
        
        Logger.info("Added \(app.name) to folder '\(folder.name)'")
    }
    
    /// 從文件夾中移除應用（通用方法，支援多種場景）
    /// - Parameters:
    ///   - app: 要移除的應用
    ///   - folder: 目標文件夾
    ///   - placement: 移除後的放置方式
    func removeAppFromFolder(app: AppItem, folder: AppFolder, placement: FolderRemovalPlacement = .updateDisplay) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        
        var updatedFolder = folders[folderIndex]
        updatedFolder.apps.removeAll { $0.id == app.id }
        
        let folderDisplayIndex = displayItems.firstIndex {
            if case .folder(let f) = $0 { return f.id == folder.id }
            return false
        }
        
        // 處理文件夾刪除邏輯
        if updatedFolder.apps.count <= 1 {
            let lastApp = updatedFolder.apps.first
            folders.remove(at: folderIndex)
            
            if let idx = folderDisplayIndex {
                displayItems.remove(at: idx)
                // 如果有剩餘的 app，根據放置方式處理
                if let lastApp = lastApp {
                    switch placement {
                    case .updateDisplay:
                        displayItems.insert(.app(lastApp), at: idx)
                    case .floatingDrag:
                        displayItems.insert(.app(lastApp), at: idx)
                    case .appendToEnd:
                        displayItems.append(.app(lastApp))
                    }
                }
            }
        } else {
            folders[folderIndex] = updatedFolder
            if let idx = folderDisplayIndex {
                displayItems[idx] = .folder(updatedFolder)
            }
        }
        
        // 根據放置方式處理被移出的應用
        switch placement {
        case .updateDisplay:
            updateDisplayItems()
        case .floatingDrag:
            break  // 不做額外處理，讓浮動拖曳邏輯自己決定
        case .appendToEnd:
            displayItems.append(.app(app))
        }
        
        Logger.info("Removed \(app.name) from folder '\(folder.name)' with placement: \(placement)")
    }
    
    /// 放置方式枚舉
    enum FolderRemovalPlacement {
        case updateDisplay      // 正常移除並更新顯示
        case floatingDrag       // 浮動拖曳模式（不更新顯示）
        case appendToEnd        // 移到列表末尾
    }
    
    /// 將應用插入到指定位置
    func insertAppAt(app: AppItem, index: Int) {
        let safeIndex = min(max(0, index), displayItems.count)
        displayItems.insert(.app(app), at: safeIndex)
        Logger.info("Inserted \(app.name) at index \(safeIndex)")
    }
    
    /// 重新排序文件夾內的應用
    func reorderAppsInFolder(_ folder: AppFolder, from sourceIndex: Int, to destinationIndex: Int) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }),
              sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < folders[folderIndex].apps.count,
              destinationIndex >= 0, destinationIndex < folders[folderIndex].apps.count else {
            return
        }
        
        var updatedFolder = folders[folderIndex]
        let app = updatedFolder.apps.remove(at: sourceIndex)
        updatedFolder.apps.insert(app, at: destinationIndex)
        folders[folderIndex] = updatedFolder
        
        // 更新 displayItems 中的文件夾
        if let displayIndex = displayItems.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folder.id }
            return false
        }) {
            displayItems[displayIndex] = .folder(updatedFolder)
        }
        
        Logger.info("Reordered apps in folder '\(folder.name)': moved from \(sourceIndex) to \(destinationIndex)")
    }
    
    /// 重命名文件夾
    func renameFolder(_ folder: AppFolder, to newName: String) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        
        var updatedFolder = folders[folderIndex]
        updatedFolder.name = newName
        folders[folderIndex] = updatedFolder
        updateDisplayItems()
        
        Logger.info("Renamed folder to '\(newName)'")
    }
    
    /// 刪除文件夾（應用會回到主畫面）
    func deleteFolder(_ folder: AppFolder) {
        folders.removeAll { $0.id == folder.id }
        updateDisplayItems()
        Logger.info("Deleted folder '\(folder.name)'")
    }
    
    /// 根據 ID 查找顯示項目的索引
    func indexOfItem(withId id: UUID) -> Int? {
        displayItems.firstIndex { $0.id == id }
    }
    
    /// 根據位置查找項目
    func itemAtPosition(_ position: CGPoint, in geometry: GeometryProxy, layoutConfig: GridLayoutConfig) -> LaunchpadDisplayItem? {
        // 計算網格位置
        let itemWidth = GridLayoutManager.itemWidth
        let itemHeight = GridLayoutManager.itemWidth + GridLayoutManager.labelHeight
        let columns = layoutConfig.columns
        
        let gridWidth = layoutConfig.gridWidth
        let startX = (geometry.size.width - gridWidth) / 2
        
        let col = Int((position.x - startX) / itemWidth)
        let row = Int(position.y / itemHeight)
        
        let index = row * columns + col
        
        guard index >= 0, index < displayItems.count else {
            return nil
        }
        
        return displayItems[index]
    }
}
