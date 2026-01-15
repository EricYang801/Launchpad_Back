//
//  AppIconCache.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 應用程式圖示快取管理器
/// 負責非同步加載和緩存應用程式圖示，減少重複讀取磁碟的開銷
class AppIconCache {
    static let shared = AppIconCache()
    
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.launchpad.AppIconCache", qos: .userInitiated)
    private let lock = NSLock()
    
    private init() {}
    
    /// 獲取應用程式圖示
    /// - Parameter path: 應用程式路徑
    /// - Returns: NSImage 或 nil
    func getIcon(for path: String) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        
        if let cachedIcon = cache[path] {
            return cachedIcon
        }
        
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache[path] = icon
        return icon
    }
    
    /// 非同步獲取應用程式圖示
    /// - Parameters:
    ///   - path: 應用程式路徑
    ///   - completion: 完成回呼
    func getIconAsync(for path: String, completion: @escaping (NSImage?) -> Void) {
        queue.async { [weak self] in
            let icon = self?.getIcon(for: path)
            DispatchQueue.main.async {
                completion(icon)
            }
        }
    }
    
    /// 清空快取
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
    
    /// 獲取快取統計信息
    func getCacheStatistics() -> (count: Int, size: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let count = cache.count
        let estimatedSize = count * 256 // 粗略估計每個圖示約 256KB
        let sizeInMB = Double(estimatedSize) / (1024 * 1024)
        
        return (count, String(format: "%.2f MB", sizeInMB))
    }
}
