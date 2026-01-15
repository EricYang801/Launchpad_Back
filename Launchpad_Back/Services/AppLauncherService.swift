//
//  AppLauncherService.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 應用程式啟動服務
/// 負責啟動應用程式的核心邏輯
class AppLauncherService {
    private let workspace = NSWorkspace.shared
    
    /// 啟動應用程式
    /// - Parameter app: 要啟動的應用程式
    /// - Returns: 啟動是否成功
    @discardableResult
    func launch(_ app: AppItem) -> Bool {
        let appURL = URL(fileURLWithPath: app.path)
        
        // 嘗試直接打開應用程式
        if workspace.open(appURL) {
            return true
        }
        
        // 如果失敗，嘗試使用 Bundle ID
        if !app.bundleID.isEmpty,
           let bundleURL = workspace.urlForApplication(withBundleIdentifier: app.bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            
            var success = false
            let semaphore = DispatchSemaphore(value: 0)
            
            workspace.openApplication(at: bundleURL, configuration: configuration) { _, error in
                success = error == nil
                semaphore.signal()
            }
            
            semaphore.wait(timeout: .now() + 5)
            return success
        }
        
        return false
    }
    
    /// 啟動應用程式（非同步）
    /// - Parameters:
    ///   - app: 要啟動的應用程式
    ///   - completion: 完成回呼
    func launchAsync(_ app: AppItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.launch(app)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
