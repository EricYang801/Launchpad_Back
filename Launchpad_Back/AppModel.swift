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
    let isSystemApp: Bool
    
    var appIcon: NSImage? {
        AppIconCache.shared.getIcon(for: path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}

// 圖示快取類別
class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "AppIconCache", qos: .userInitiated)
    
    private init() {}
    
    func getIcon(for path: String) -> NSImage? {
        queue.sync {
            if let cachedIcon = cache[path] {
                return cachedIcon
            }
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache[path] = icon
            return icon
        }
    }
    
    func clearCache() {
        queue.sync { cache.removeAll() }
    }
}

class LaunchpadViewModel: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var isLoading = true
    
    private let scanPaths = [
        ("/System/Applications", true),
        ("/System/Applications/Utilities", true),
        ("/Applications", false)
    ]
    
    func loadInstalledApps() {
        DispatchQueue.global(qos: .background).async {
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)
            var allApps: [AppItem] = []
            let lock = NSLock()
            
            // 並行掃描所有路徑
            for (path, isSystemApp) in self.scanPaths {
                group.enter()
                queue.async {
                    let apps = self.scanAppsInDirectory(path, isSystemApp: isSystemApp)
                    lock.lock()
                    allApps.append(contentsOf: apps)
                    lock.unlock()
                    group.leave()
                }
            }
            
            group.wait()
            
            // 去重並排序
            let uniqueApps = self.removeDuplicates(from: allApps)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.apps = uniqueApps
                self.isLoading = false
            }
        }
    }
    
    private func scanAppsInDirectory(_ path: String, isSystemApp: Bool) -> [AppItem] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
        
        return contents
            .filter { $0.hasSuffix(".app") }
            .compactMap { createAppItem(from: $0, in: path, isSystemApp: isSystemApp) }
    }
    
    private func createAppItem(from fileName: String, in directory: String, isSystemApp: Bool) -> AppItem? {
        let fullPath = "\(directory)/\(fileName)"
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        
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
    
    func launchApp(_ app: AppItem) {
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: app.path)
        
        if !workspace.open(appURL) && !app.bundleID.isEmpty {
            // 嘗試使用 Bundle ID 啟動
            if let bundleURL = workspace.urlForApplication(withBundleIdentifier: app.bundleID) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                workspace.openApplication(at: bundleURL, configuration: configuration) { _, _ in }
            }
        }
    }
    
    func refreshApps() {
        isLoading = true
        apps.removeAll()
        AppIconCache.shared.clearCache()
        loadInstalledApps()
    }
    
}
