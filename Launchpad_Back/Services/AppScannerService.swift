//
//  AppScannerService.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 應用程式掃描服務
/// 負責從系統目錄掃描安裝的應用程式
class AppScannerService {
    private let fileManager = FileManager.default
    
    private let scanPaths: [(path: String, isSystemApp: Bool)] = [
        ("/System/Applications", true),
        ("/System/Applications/Utilities", true),
        ("/Applications", false)
    ]
    
    /// 掃描所有已安裝的應用程式
    /// - Returns: 應用程式陣列
    func scanInstalledApps() -> [AppItem] {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        var allApps: [AppItem] = []
        let lock = NSLock()
        
        // 並行掃描所有路徑
        for (path, isSystemApp) in scanPaths {
            group.enter()
            queue.async { [weak self] in
                defer { group.leave() }
                let apps = self?.scanAppsInDirectory(path, isSystemApp: isSystemApp) ?? []
                
                lock.lock()
                allApps.append(contentsOf: apps)
                lock.unlock()
            }
        }
        
        group.wait()
        
        // 去重並排序
        return removeDuplicates(from: allApps)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// 在指定目錄中掃描應用程式
    /// - Parameters:
    ///   - path: 目錄路徑
    ///   - isSystemApp: 是否為系統應用程式
    /// - Returns: 應用程式陣列
    private func scanAppsInDirectory(_ path: String, isSystemApp: Bool) -> [AppItem] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }
        
        return contents
            .filter { $0.hasSuffix(".app") }
            .compactMap { createAppItem(from: $0, in: path, isSystemApp: isSystemApp) }
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
        
        let infoPlistPath = "\(fullPath)/Contents/Info.plist"
        let infoPlist = NSDictionary(contentsOfFile: infoPlistPath)
        
        let appName = infoPlist?["CFBundleDisplayName"] as? String ??
            infoPlist?["CFBundleName"] as? String ??
            fileName.replacingOccurrences(of: ".app", with: "")
        
        let bundleID = infoPlist?["CFBundleIdentifier"] as? String ?? ""
        
        return AppItem(
            name: appName,
            bundleID: bundleID,
            path: fullPath,
            isSystemApp: isSystemApp
        )
    }
    
    /// 移除重複的應用程式
    /// - Parameter apps: 應用程式陣列
    /// - Returns: 去重後的應用程式陣列
    private func removeDuplicates(from apps: [AppItem]) -> [AppItem] {
        var uniqueApps: [AppItem] = []
        var seenIdentifiers: Set<String> = []
        
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
