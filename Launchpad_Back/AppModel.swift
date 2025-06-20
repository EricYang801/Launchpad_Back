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
    var appIcon: NSImage?
    
    // 為了 Hashable 協議，我們不包含 NSImage 在比較中
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        return lhs.bundleID == rhs.bundleID
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
            var installedApps: [AppItem] = []
            
            // 掃描系統應用程式資料夾
            let systemAppsPath = "/System/Applications"
            let userAppsPath = "/Applications"
            
            installedApps.append(contentsOf: self.scanAppsInDirectory(systemAppsPath, isSystemApp: true))
            installedApps.append(contentsOf: self.scanAppsInDirectory(userAppsPath, isSystemApp: false))
            
            // 去除重複的應用（基於 bundleID）
            var uniqueApps: [AppItem] = []
            var seenBundleIDs: Set<String> = []
            
            for app in installedApps {
                if !seenBundleIDs.contains(app.bundleID) && !app.bundleID.isEmpty {
                    seenBundleIDs.insert(app.bundleID)
                    uniqueApps.append(app)
                }
            }
            
            // 按照名稱排序
            uniqueApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.apps = uniqueApps
                self.isLoading = false
            }
        }
    }
    
    private func scanAppsInDirectory(_ path: String, isSystemApp: Bool) -> [AppItem] {
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return apps
        }
        
        for item in contents {
            let fullPath = "\(path)/\(item)"
            
            // 只處理 .app 檔案
            guard item.hasSuffix(".app") else { continue }
            
            // 檢查是否為資料夾
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            // 讀取 Info.plist
            let infoPlistPath = "\(fullPath)/Contents/Info.plist"
            guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else { continue }
            
            // 獲取應用程式資訊
            let appName = infoPlist["CFBundleDisplayName"] as? String ??
                         infoPlist["CFBundleName"] as? String ??
                         item.replacingOccurrences(of: ".app", with: "")
            
            let bundleID = infoPlist["CFBundleIdentifier"] as? String ?? ""
            
            // 跳過一些系統工具程式
            let skipApps = ["ActivityMonitor", "AirPort Utility", "Audio MIDI Setup", "Bluetooth Screen Sharing", "Boot Camp Assistant", "ColorSync Utility", "Console", "Disk Utility", "Grapher", "Keychain Access", "Migration Assistant", "System Information", "VoiceOver Utility"]
            
            if skipApps.contains(appName) { continue }
            
            // 獲取應用程式圖示
            let appIcon = self.getAppIcon(at: fullPath)
            
            let appItem = AppItem(
                name: appName,
                bundleID: bundleID,
                path: fullPath,
                isSystemApp: isSystemApp,
                appIcon: appIcon
            )
            
            apps.append(appItem)
        }
        
        return apps
    }
    
    private func getAppIcon(at appPath: String) -> NSImage? {
        let bundle = Bundle(path: appPath)
        let iconPath = bundle?.path(forResource: "AppIcon", ofType: "icns") ??
                      bundle?.path(forResource: bundle?.infoDictionary?["CFBundleIconFile"] as? String ?? "", ofType: "icns")
        
        if let iconPath = iconPath {
            return NSImage(contentsOfFile: iconPath)
        }
        
        // 如果找不到圖示，使用 NSWorkspace 來獲取
        return NSWorkspace.shared.icon(forFile: appPath)
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
        loadInstalledApps()
    }
}
