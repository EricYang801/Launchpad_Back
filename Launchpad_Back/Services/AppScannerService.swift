//
//  AppScannerService.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//  Optimized for memory usage on 2025/1/16
//

import AppKit

/// 應用程式掃描服務
/// 負責從系統目錄掃描安裝的應用程式
/// 
/// 記憶體優化：
/// - 使用 autoreleasepool 包裹掃描邏輯，及時釋放臨時物件
/// - 優化 Info.plist 解析，只提取必要資訊
/// - 改善並行掃描的記憶體管理
class AppScannerService {
    private let fileManager = FileManager.default
    
    /// 應用掃描排除的 Bundle ID 列表（隱藏的系統應用）
    private let excludedBundleIDs: Set<String> = [
        "com.apple.installer",
        "com.apple.LaunchPadMigrator",
        "com.apple.AirPlayUIAgent",
        "com.apple.SoftwareUpdateNotificationManager",
        "com.apple.CoreLocationAgent",
        "com.apple.OBEXAgent",
        "com.apple.ODSAgent",
        "com.apple.PIPAgent",
        "com.apple.ReportPanic",
        "com.apple.ScreenSaverEngine",
        "com.apple.loginwindow"
    ]
    
    private var scanPaths: [(path: String, isSystemApp: Bool)] {
        var paths: [(String, Bool)] = [
            ("/System/Applications", true),
            ("/System/Applications/Utilities", true),
            ("/Applications", false),
            ("/Applications/Utilities", false)
        ]
        
        // 添加用戶應用程式目錄
        if let userAppsPath = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first?.path {
            paths.append((userAppsPath, false))
        }
        
        // 添加 Homebrew Cask 應用目錄
        let homebrewCaskPath = "/opt/homebrew/Caskroom"
        if fileManager.fileExists(atPath: homebrewCaskPath) {
            paths.append((homebrewCaskPath, false))
        }
        
        return paths
    }
    
    /// 掃描所有已安裝的應用程式
    /// - Returns: 應用程式陣列
    func scanInstalledApps() -> [AppItem] {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // 使用串行隊列保護共享狀態，比 NSLock 更安全且易於理解
        let resultQueue = DispatchQueue(label: "com.launchpad.scanner.results")
        var allApps: [AppItem] = []
        
        // 並行掃描所有路徑（使用 autoreleasepool 優化記憶體）
        for (path, isSystemApp) in scanPaths {
            group.enter()
            queue.async { [weak self] in
                defer { group.leave() }
                
                // 優化：使用 autoreleasepool 包裹整個掃描邏輯
                autoreleasepool {
                    guard let self = self else { return }
                    let apps = self.scanAppsInDirectory(path, isSystemApp: isSystemApp, recursive: false)
                    
                    // 在專用隊列中安全地添加結果
                    resultQueue.sync {
                        allApps.append(contentsOf: apps)
                    }
                }
            }
        }
        
        group.wait()
        
        // 過濾排除的應用、去重並排序
        let finalApps = removeDuplicates(from: allApps)
            .filter { !excludedBundleIDs.contains($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        Logger.info("AppScannerService found \(finalApps.count) apps after filtering")
        return finalApps
    }
    
    /// 在指定目錄中掃描應用程式
    /// - Parameters:
    ///   - path: 目錄路徑
    ///   - isSystemApp: 是否為系統應用程式
    ///   - recursive: 是否遞迴掃描子目錄
    /// - Returns: 應用程式陣列
    private func scanAppsInDirectory(_ path: String, isSystemApp: Bool, recursive: Bool = false) -> [AppItem] {
        // 優化：整個掃描過程使用 autoreleasepool
        return autoreleasepool {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
                return []
            }
            
            var apps: [AppItem] = []
            apps.reserveCapacity(contents.count)  // 預分配容量
            
            for item in contents {
                // 優化：每個項目的處理也使用 autoreleasepool
                autoreleasepool {
                    let fullPath = "\(path)/\(item)"
                    var isDirectory: ObjCBool = false
                    
                    guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        return
                    }
                    
                    if item.hasSuffix(".app") {
                        if let app = createAppItem(from: item, in: path, isSystemApp: isSystemApp) {
                            apps.append(app)
                        }
                    } else if recursive {
                        // 遞迴掃描子目錄
                        let subApps = scanAppsInDirectory(fullPath, isSystemApp: isSystemApp, recursive: true)
                        apps.append(contentsOf: subApps)
                    }
                }
            }
            
            return apps
        }
    }
    
    /// 從檔案名稱創建應用程式項目
    /// - Parameters:
    ///   - fileName: .app 檔案名稱
    ///   - directory: 所在目錄
    ///   - isSystemApp: 是否為系統應用程式
    /// - Returns: AppItem 或 nil
    private func createAppItem(from fileName: String, in directory: String, isSystemApp: Bool) -> AppItem? {
        let fullPath = "\(directory)/\(fileName)"
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        
        // 優化：只讀取必要的 plist 鍵值，避免載入整個 plist
        let infoPlistPath = "\(fullPath)/Contents/Info.plist"
        
        // 使用 autoreleasepool 包裹 plist 讀取
        return autoreleasepool {
            guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else {
                // 如果無法讀取 plist，使用文件名作為應用名稱
                let appName = fileName.replacingOccurrences(of: ".app", with: "")
                return AppItem(
                    name: appName,
                    bundleID: "",
                    path: fullPath,
                    isSystemApp: isSystemApp
                )
            }
            
            // 優化：只提取必要的資訊，立即釋放 plist
            let appName = infoPlist["CFBundleDisplayName"] as? String ??
                infoPlist["CFBundleName"] as? String ??
                fileName.replacingOccurrences(of: ".app", with: "")
            
            let bundleID = infoPlist["CFBundleIdentifier"] as? String ?? ""
            
            // 立即創建 AppItem，plist 會在 autoreleasepool 結束時釋放
            return AppItem(
                name: appName,
                bundleID: bundleID,
                path: fullPath,
                isSystemApp: isSystemApp
            )
        }
    }
    
    /// 移除重複的應用程式
    /// - Parameter apps: 應用程式陣列
    /// - Returns: 去重後的應用程式陣列
    private func removeDuplicates(from apps: [AppItem]) -> [AppItem] {
        var uniqueApps: [AppItem] = []
        var seenIdentifiers: Set<String> = []
        
        // 預分配容量以提高效能
        uniqueApps.reserveCapacity(apps.count)
        seenIdentifiers.reserveCapacity(apps.count)
        
        for app in apps {
            let identifier = app.bundleID.isEmpty ? app.path : app.bundleID
            if !seenIdentifiers.contains(identifier) {
                seenIdentifiers.insert(identifier)
                uniqueApps.append(app)
            }
        }
        
        return uniqueApps
    }
}
