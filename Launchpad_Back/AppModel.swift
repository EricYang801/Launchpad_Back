//
//  AppModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI
import AppKit
import Combine

struct AppItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let path: String
    var isSystemApp: Bool = false
    
    // 使用計算屬性延遲載入圖示
    var appIcon: NSImage? {
        return AppIconCache.shared.getIcon(for: path)
    }
    
    // 為了 Hashable 協議，我們不包含 NSImage 在比較中
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        return lhs.bundleID == rhs.bundleID
    }
}

// 圖示快取類別
class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "AppIconCache", qos: .userInitiated)
    
    private init() {}
    
    func getIcon(for path: String) -> NSImage? {
        return queue.sync {
            if let cachedIcon = cache[path] {
                return cachedIcon
            }
            
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache[path] = icon
            return icon
        }
    }
    
    func clearCache() {
        queue.sync {
            cache.removeAll()
        }
    }
}

class LaunchpadViewModel: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var searchText: String = ""
    @Published var selectedApp: AppItem?
    @Published var currentPage: Int = 0
    @Published var isLoading: Bool = true
    
    let appsPerPage = 35  // 7x5 網格 = 35 個應用程式每頁
    
    init() {
        loadInstalledApps()
    }
    
    func loadInstalledApps() {
        DispatchQueue.global(qos: .background).async {
            print("🔍 開始掃描應用程式...")
            
            // 使用並行掃描來提升速度
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            var systemApps: [AppItem] = []
            var systemUtilities: [AppItem] = []
            var userApps: [AppItem] = []
            
            // 並行掃描系統應用程式
            group.enter()
            queue.async {
                systemApps = self.scanAppsInDirectory("/System/Applications", isSystemApp: true)
                print("📱 系統應用程式數量: \(systemApps.count)")
                group.leave()
            }
            
            // 並行掃描系統工具程式
            group.enter()
            queue.async {
                systemUtilities = self.scanAppsInDirectory("/System/Applications/Utilities", isSystemApp: true)
                print("📱 系統工具程式數量: \(systemUtilities.count)")
                group.leave()
            }
            
            // 並行掃描用戶應用程式
            group.enter()
            queue.async {
                userApps = self.scanAppsInDirectory("/Applications", isSystemApp: false)
                print("📱 用戶應用程式數量: \(userApps.count)")
                group.leave()
            }
            
            // 等待所有掃描完成
            group.wait()
            
            var installedApps: [AppItem] = []
            installedApps.append(contentsOf: systemApps)
            installedApps.append(contentsOf: systemUtilities)
            installedApps.append(contentsOf: userApps)
            
            print("📱 總應用程式數量（去重前）: \(installedApps.count)")
            print("  - 系統應用: \(systemApps.count)")
            print("  - 系統工具: \(systemUtilities.count)")
            print("  - 用戶應用: \(userApps.count)")
            
            // 去除重複的應用（基於 bundleID，但允許沒有 bundleID 的應用）
            var uniqueApps: [AppItem] = []
            var seenBundleIDs: Set<String> = []
            var seenPaths: Set<String> = []
            
            for app in installedApps {
                let identifier = app.bundleID.isEmpty ? app.path : app.bundleID
                
                if !seenBundleIDs.contains(identifier) && !seenPaths.contains(app.path) {
                    seenBundleIDs.insert(identifier)
                    seenPaths.insert(app.path)
                    uniqueApps.append(app)
                }
            }
            
            // 按照名稱排序
            uniqueApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            print("✅ 最終應用程式數量: \(uniqueApps.count)")
            if uniqueApps.count < 10 {
                print("📋 應用程式列表:")
                for app in uniqueApps {
                    print("  - \(app.name) (\(app.bundleID))")
                }
            }
            
            DispatchQueue.main.async {
                self.apps = uniqueApps
                self.isLoading = false
            }
        }
    }
    
    private func scanAppsInDirectory(_ path: String, isSystemApp: Bool) -> [AppItem] {
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        print("🔍 掃描目錄: \(path)")
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            print("❌ 無法讀取目錄: \(path)")
            return apps
        }
        
        // 只取出 .app 檔案，提前過濾
        let appFiles = contents.filter { $0.hasSuffix(".app") }
        print("📁 找到 \(appFiles.count) 個應用程式在 \(path)")
        
        // 批次檢查檔案是否存在，減少系統調用
        let validApps = appFiles.compactMap { item -> (String, String)? in
            let fullPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { 
                return nil
            }
            
            return (item, fullPath)
        }
        
        for (item, fullPath) in validApps {
            // 快速讀取 Info.plist，失敗時使用檔案名稱
            let infoPlistPath = "\(fullPath)/Contents/Info.plist"
            
            var appName: String
            var bundleID: String = ""
            
            if let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) {
                appName = infoPlist["CFBundleDisplayName"] as? String ??
                         infoPlist["CFBundleName"] as? String ??
                         item.replacingOccurrences(of: ".app", with: "")
                
                bundleID = infoPlist["CFBundleIdentifier"] as? String ?? ""
            } else {
                print("⚠️ 無法讀取 Info.plist: \(item)")
                appName = item.replacingOccurrences(of: ".app", with: "")
            }
            
            // 跳過不需要的系統工具程式
            let skipApps = ["Boot Camp Assistant", "Migration Assistant"]
            if skipApps.contains(appName) { continue }
            
            // 延遲載入圖示（在需要時才載入）
            let appItem = AppItem(
                name: appName,
                bundleID: bundleID,
                path: fullPath,
                isSystemApp: isSystemApp
            )
            
            apps.append(appItem)
        }
        
        return apps
    }
    
    private func getAppIcon(at appPath: String) -> NSImage? {
        // 方法 1: 使用 NSWorkspace (最可靠)
        let workspaceIcon = NSWorkspace.shared.icon(forFile: appPath)
        if workspaceIcon.size.width > 32 {
            return workspaceIcon
        }
        
        // 方法 2: 從 Bundle 獲取圖示
        guard let bundle = Bundle(path: appPath) else {
            return workspaceIcon // 回退到 workspace 圖示
        }
        
        // 嘗試獲取圖示檔案名稱
        let iconFileName = bundle.infoDictionary?["CFBundleIconFile"] as? String
        
        // 搜尋可能的圖示路徑
        let possibleIconNames = [
            iconFileName,
            "AppIcon",
            "app", 
            "icon",
            "Icon",
            bundle.infoDictionary?["CFBundleName"] as? String
        ].compactMap { $0 }
        
        for iconName in possibleIconNames {
            // 嘗試不同的副檔名
            let extensions = ["icns", "png", "ico"]
            for ext in extensions {
                if let iconPath = bundle.path(forResource: iconName, ofType: ext),
                   let icon = NSImage(contentsOfFile: iconPath) {
                    return icon
                }
            }
            
            // 嘗試沒有副檔名的檔案
            if let iconPath = bundle.path(forResource: iconName, ofType: nil),
               let icon = NSImage(contentsOfFile: iconPath) {
                return icon
            }
        }
        
        // 方法 3: 搜尋 Resources 資料夾中的圖示檔案
        let resourcesPath = "\(appPath)/Contents/Resources"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcesPath) {
            for file in contents {
                if file.lowercased().contains("icon") && 
                   (file.hasSuffix(".icns") || file.hasSuffix(".png")) {
                    let iconPath = "\(resourcesPath)/\(file)"
                    if let icon = NSImage(contentsOfFile: iconPath) {
                        return icon
                    }
                }
            }
        }
        
        return workspaceIcon // 最終回退
    }

    var filteredApps: [AppItem] {
        if searchText.isEmpty {
            return apps
        } else {
            let filtered = apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleID.localizedCaseInsensitiveContains(searchText)
            }
            
            // 自動重置到第一頁當搜尋結果改變時
            DispatchQueue.main.async {
                if self.currentPage >= self.totalPages && self.totalPages > 0 {
                    self.currentPage = 0
                }
            }
            
            return filtered
        }
    }
    
    var totalPages: Int {
        return max(1, (filteredApps.count + appsPerPage - 1) / appsPerPage)
    }
    
    func appsForPage(_ page: Int) -> [AppItem] {
        let startIndex = page * appsPerPage
        let endIndex = min(startIndex + appsPerPage, filteredApps.count)
        
        if startIndex >= filteredApps.count {
            return []
        }
        
        return Array(filteredApps[startIndex..<endIndex])
    }
    
    func launchApp(_ app: AppItem) {
        selectedApp = app
        
        // 使用 NSWorkspace 啟動應用程式
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: app.path)
        
        print("嘗試啟動應用: \(app.name) at \(app.path)")
        
        // 使用 open 方法啟動應用程式
        let success = workspace.open(appURL)
        
        if success {
            print("✅ 成功啟動應用: \(app.name)")
        } else {
            print("❌ 無法啟動應用: \(app.name)")
            
            // 嘗試使用現代 API 和 bundle identifier 啟動
            if !app.bundleID.isEmpty {
                let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleID)
                if let appURL = appURL {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = true
                    
                    workspace.openApplication(at: appURL, 
                                            configuration: configuration) { app, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("❌ 使用 Bundle ID 啟動失敗: \(error.localizedDescription)")
                            } else {
                                print("✅ 使用 Bundle ID 成功啟動應用: \(app?.localizedName ?? "Unknown")")
                            }
                        }
                    }
                } else {
                    print("❌ 無法找到 Bundle ID 對應的應用: \(app.bundleID)")
                }
            }
        }
    }
    
    func refreshApps() {
        isLoading = true
        apps.removeAll()
        currentPage = 0
        AppIconCache.shared.clearCache() // 清除圖示快取
        loadInstalledApps()
    }
}
