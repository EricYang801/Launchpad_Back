//
//  LaunchpadViewModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//  Optimized for memory usage on 2025/1/16
//

import SwiftUI
import Combine

private struct SearchIndexEntry {
    let app: AppItem
    let searchText: String
}

/// 主要的 Launchpad ViewModel
/// 負責應用程式列表的管理和狀態
/// 
/// 記憶體優化：
/// - 使用防抖動機制減少頻繁的 UserDefaults 寫入
/// - 優化 @Published 屬性使用
/// - 改善記憶體釋放邏輯
final class LaunchpadViewModel: ObservableObject {
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
    @Published private(set) var searchableApps: [AppItem] = []
    
    private let scannerService: AppScannerService
    private let launcherService: AppLauncherService
    private let defaults: UserDefaults
    private var searchIndex: [SearchIndexEntry] = []
    
    // 持久化存儲鍵
    private let orderKey = "launchpad_item_order"
    private let foldersKey = "launchpad_folders"
    
    // 優化：防抖動計時器，減少頻繁的 UserDefaults 寫入
    private var saveOrderWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5
    
    // 優化：快取當前頁面信息，用於圖標快取管理
    private var currentPage: Int = 0
    private var itemsPerPage: Int = 35
    
    init(
        scannerService: AppScannerService = AppScannerService(),
        launcherService: AppLauncherService = AppLauncherService(),
        defaults: UserDefaults = .standard
    ) {
        self.scannerService = scannerService
        self.launcherService = launcherService
        self.defaults = defaults
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
            let apps = self?.scannerService.scanInstalledApps() ?? []
            
            DispatchQueue.main.async {
                let searchState = self?.buildSearchState(from: apps)
                self?.apps = apps
                self?.searchableApps = searchState?.apps ?? []
                self?.searchIndex = searchState?.index ?? []
                self?.initializeDisplayItems()
                self?.isLoading = false
                Logger.info("App loading completed. Found \(apps.count) applications")
                
                // 優化：更新圖標快取的活躍頁面
                self?.updateIconCacheActivePage()
            }
        }
    }
    
    /// 根據最新的 apps / folders 重新同步顯示列表，保留現有排序。
    private func reconcileDisplayItems() {
        let appsInFolders = Set(folders.flatMap { $0.apps.map(\.stableIdentifier) })
        var standaloneAppsByIdentifier = Dictionary(
            uniqueKeysWithValues: apps
                .filter { !appsInFolders.contains($0.stableIdentifier) }
                .map { ($0.stableIdentifier, $0) }
        )
        var foldersById = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var reconciledItems: [LaunchpadDisplayItem] = []
        
        for item in displayItems {
            switch item {
            case .app(let app):
                let key = app.stableIdentifier
                guard let latestApp = standaloneAppsByIdentifier.removeValue(forKey: key) else {
                    continue
                }
                reconciledItems.append(.app(latestApp))
            case .folder(let folder):
                guard let latestFolder = foldersById.removeValue(forKey: folder.id) else {
                    continue
                }
                reconciledItems.append(.folder(latestFolder))
            }
        }
        
        let remainingApps = standaloneAppsByIdentifier.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(LaunchpadDisplayItem.app)
        let remainingFolders = foldersById.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(LaunchpadDisplayItem.folder)
        
        displayItems = reconciledItems + remainingApps + remainingFolders
    }
    
    /// 初始化顯示項目列表（首次載入時按名稱排序，或從保存的順序載入）
    private func initializeDisplayItems() {
        // 嘗試載入保存的文件夾
        loadFolders()
        
        // 獲取所有在文件夾中的應用 ID
        let appsInFolders = Set(folders.flatMap { $0.apps.map(\.stableIdentifier) })
        let standaloneAppsByIdentifier = Dictionary(
            uniqueKeysWithValues: apps
                .filter { !appsInFolders.contains($0.stableIdentifier) }
                .map { ($0.stableIdentifier, $0) }
        )
        let foldersById = Dictionary(uniqueKeysWithValues: folders.map { ($0.id.uuidString, $0) })
        
        // 嘗試載入保存的順序
        if let savedOrder = loadOrder() {
            var orderedItems: [LaunchpadDisplayItem] = []
            var remainingApps = standaloneAppsByIdentifier
            var remainingFolders = foldersById
            
            // 按保存的順序排列
            for itemKey in savedOrder {
                // 檢查是否為文件夾 (格式: "folder:UUID")
                if itemKey.hasPrefix("folder:") {
                    let folderId = String(itemKey.dropFirst(7))
                    if let folder = remainingFolders.removeValue(forKey: folderId) {
                        orderedItems.append(.folder(folder))
                    }
                }
                // 檢查是否為應用 (格式: "app:stableIdentifier")
                else if itemKey.hasPrefix("app:") {
                    let appIdentifier = String(itemKey.dropFirst(4))
                    if let app = remainingApps.removeValue(forKey: appIdentifier) {
                        orderedItems.append(.app(app))
                    }
                }
            }
            
            // 添加新安裝的應用（不在保存順序中的）
            let newApps = remainingApps.values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(LaunchpadDisplayItem.app)
            let newFolders = remainingFolders.values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(LaunchpadDisplayItem.folder)
            orderedItems.append(contentsOf: newApps)
            orderedItems.append(contentsOf: newFolders)
            
            displayItems = orderedItems
            Logger.info("Loaded saved order with \(orderedItems.count) items")
        } else {
            // 沒有保存的順序，按名稱排序
            var items: [LaunchpadDisplayItem] = []
            
            // 添加不在文件夾中的應用
            let standaloneApps = apps.filter { !appsInFolders.contains($0.stableIdentifier) }
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

    private func defaultSortedDisplayItems() -> [LaunchpadDisplayItem] {
        apps
            .map(LaunchpadDisplayItem.app)
            .sorted { item1, item2 in
                item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
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
        let order = displayItems.map(\.persistenceKey)
        
        // 優化：批次寫入，減少 I/O 操作
        defaults.set(order, forKey: orderKey)
        saveFolders(to: defaults)
        
        Logger.debug("Saved order with \(order.count) items and \(folders.count) folders")
    }
    
    /// 保存當前順序（公開方法，用於需要立即保存的場景）
    func saveOrder() {
        saveOrderImmediately()
    }
    
    /// 載入保存的順序
    private func loadOrder() -> [String]? {
        defaults.stringArray(forKey: orderKey)
    }
    
    /// 保存文件夾（優化：接受 UserDefaults 參數，避免重複獲取）
    private func saveFolders(to defaults: UserDefaults? = nil) {
        let defaults = defaults ?? self.defaults
        let folderData = folders.map { folder -> [String: Any] in
            [
                "id": folder.id.uuidString,
                "name": folder.name,
                "appIdentifiers": folder.apps.map(\.stableIdentifier)
            ]
        }
        defaults.set(folderData, forKey: foldersKey)
    }
    
    /// 載入文件夾
    private func loadFolders() {
        guard let folderData = defaults.array(forKey: foldersKey) as? [[String: Any]] else {
            return
        }
        
        folders = folderData.compactMap { data -> AppFolder? in
            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = data["name"] as? String else {
                return nil
            }
            
            // 支援舊格式 (appIds / appBundleIds) 和新格式 (appIdentifiers)
            let folderApps: [AppItem]
            if let identifiers = data["appIdentifiers"] as? [String] {
                folderApps = identifiers.compactMap(app(withIdentifier:))
            } else if let bundleIds = data["appBundleIds"] as? [String] {
                folderApps = bundleIds.compactMap { bundleId -> AppItem? in
                    apps.first { $0.bundleID == bundleId }
                }
            } else if let appIds = data["appIds"] as? [String] {
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
    func updateActivePage(_ page: Int, itemsPerPage: Int) {
        currentPage = page
        self.itemsPerPage = max(1, itemsPerPage)
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
        guard !displayItems.isEmpty else { return }
        
        let startIndex = max(0, (page - 1) * itemsPerPage)
        let endIndex = min(displayItems.count, (page + 2) * itemsPerPage)
        guard startIndex < endIndex else { return }
        
        let requests = displayItems[startIndex..<endIndex].compactMap { item -> (path: String, appName: String?)? in
            if case .app(let app) = item {
                return (path: app.path, appName: app.name)
            }
            return nil
        }
        
        AppIconCache.shared.preloadIcons(for: requests)
    }

    private func buildSearchState(from apps: [AppItem]) -> (apps: [AppItem], index: [SearchIndexEntry]) {
        let searchableApps = Dictionary(grouping: apps, by: \.stableIdentifier)
            .compactMapValues(\.first)
            .values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let index = searchableApps.map { app in
            SearchIndexEntry(
                app: app,
                searchText: "\(app.name)\n\(app.bundleID)\n\(app.path)".lowercased()
            )
        }

        return (searchableApps, index)
    }
    
    private func app(withIdentifier identifier: String) -> AppItem? {
        apps.first { $0.stableIdentifier == identifier }
    }
    
    func filteredApps(matching searchText: String) -> [AppItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return searchableApps
        }
        
        return searchIndex
            .filter { $0.searchText.contains(query) }
            .map(\.app)
    }
    
    func filteredDisplayItems(matching searchText: String) -> [LaunchpadDisplayItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return displayItems
        }
        
        return filteredApps(matching: query).map(LaunchpadDisplayItem.app)
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
    
    /// 重設自訂排序與文件夾，恢復為依名稱排序。
    func resetLayout() {
        saveOrderWorkItem?.cancel()
        defaults.removeObject(forKey: orderKey)
        defaults.removeObject(forKey: foldersKey)
        
        folders.removeAll()
        displayItems = defaultSortedDisplayItems()
        
        saveOrderWorkItem?.cancel()
        saveOrderImmediately()
        Logger.info("Reset launchpad layout to default alphabetical order")
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

    func moveItem(withId id: UUID, to destinationIndex: Int) {
        guard let sourceIndex = indexOfItem(withId: id) else {
            Logger.debug("moveItem(withId:): missing source item \(id)")
            return
        }
        
        moveItem(from: sourceIndex, to: destinationIndex)
    }
    
    /// 創建新文件夾（將兩個應用合併，在目標位置插入文件夾）
    @discardableResult
    func createFolder(app1: AppItem, app2: AppItem) -> AppFolder {
        let folder = AppFolder(
            name: "New Folder",
            apps: [app1, app2]
        )
        
        folders.append(folder)
        
        if let targetIndex = displayItems.firstIndex(where: {
            if case .app(let app) = $0 { return app.id == app1.id }
            return false
        }) {
            let idsToRemove = Set([app1.id, app2.id])
            let removedBeforeTarget = displayItems[..<targetIndex].reduce(into: 0) { partialResult, item in
                if idsToRemove.contains(item.id) {
                    partialResult += 1
                }
            }
            displayItems.removeAll { idsToRemove.contains($0.id) }
            let insertionIndex = max(0, targetIndex - removedBeforeTarget)
            displayItems.insert(.folder(folder), at: min(insertionIndex, displayItems.count))
        } else {
            reconcileDisplayItems()
        }
        
        Logger.info("Created folder '\(folder.name)' with apps: \(app1.name), \(app2.name)")
        return folder
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
        displayItems.removeAll { $0.id == app.id }
        
        if let folderDisplayIndex = displayItems.firstIndex(where: {
            if case .folder(let existingFolder) = $0 {
                return existingFolder.id == folder.id
            }
            return false
        }) {
            displayItems[folderDisplayIndex] = .folder(updatedFolder)
        } else {
            reconcileDisplayItems()
        }
        
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
            if let idx = folderDisplayIndex {
                let safeIndex = min(idx + 1, displayItems.count)
                displayItems.insert(.app(app), at: safeIndex)
            } else {
                displayItems.append(.app(app))
            }
            reconcileDisplayItems()
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
        displayItems.removeAll { $0.id == app.id }
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
        } else {
            reconcileDisplayItems()
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
        reconcileDisplayItems()
        
        Logger.info("Renamed folder to '\(newName)'")
    }
    
    /// 刪除文件夾（應用會回到主畫面）
    func deleteFolder(_ folder: AppFolder) {
        let reinsertionIndex = displayItems.firstIndex {
            if case .folder(let existingFolder) = $0 {
                return existingFolder.id == folder.id
            }
            return false
        } ?? displayItems.count
        
        folders.removeAll { $0.id == folder.id }
        displayItems.removeAll {
            if case .folder(let existingFolder) = $0 {
                return existingFolder.id == folder.id
            }
            return false
        }
        
        var currentIndex = reinsertionIndex
        for app in folder.apps {
            displayItems.insert(.app(app), at: min(currentIndex, displayItems.count))
            currentIndex += 1
        }
        
        reconcileDisplayItems()
        Logger.info("Deleted folder '\(folder.name)'")
    }
    
    /// 根據 ID 查找顯示項目的索引
    func indexOfItem(withId id: UUID) -> Int? {
        displayItems.firstIndex { $0.id == id }
    }
}
