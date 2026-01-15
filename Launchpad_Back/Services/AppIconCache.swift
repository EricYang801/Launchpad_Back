//
//  AppIconCache.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 應用程式圖示快取管理器
/// 負責非同步加載和緩存應用程式圖示，減少重複讀取磁碟的開銷
final class AppIconCache {
    static let shared = AppIconCache()
    
    /// 圖示快取（使用 NSCache 自動管理記憶體）
    private let cache = NSCache<NSString, NSImage>()
    
    /// 正在載入的路徑集合（防止重複載入）
    private var loadingPaths: Set<String> = []
    
    /// 訪問保護鎖
    private let lock = NSLock()
    
    /// 圖標目標尺寸（Retina 2x 顯示需要 160px）
    private let targetIconSize: CGFloat = 160
    
    private init() {
        // 設定 NSCache 限制
        cache.countLimit = 200  // 最多 200 個圖標
        cache.totalCostLimit = 100 * 1024 * 1024  // 最多 100MB
    }
    
    /// 獲取應用程式圖示（線程安全，同步操作）
    /// - Parameter path: 應用程式路徑
    /// - Returns: NSImage 或 nil
    func getIcon(for path: String) -> NSImage? {
        let key = path as NSString
        
        // 檢查快取
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }
        
        lock.lock()
        
        // 再次檢查（可能另一個線程已經加載）
        if let cachedIcon = cache.object(forKey: key) {
            lock.unlock()
            return cachedIcon
        }
        
        // 檢查是否正在載入（防止重複載入）
        if loadingPaths.contains(path) {
            lock.unlock()
            // 等待其他執行緒載入完成，然後重試
            Thread.sleep(forTimeInterval: 0.01)
            return getIcon(for: path)
        }
        
        // 標記為正在載入
        loadingPaths.insert(path)
        lock.unlock()
        
        // 載入圖示（在鎖外執行）
        let originalIcon = NSWorkspace.shared.icon(forFile: path)
        
        // 縮小圖標以節省內存
        let resizedIcon = resizeIcon(originalIcon, to: targetIconSize)
        
        // 估算圖標大小用於 NSCache 成本
        let estimatedCost = Int(targetIconSize * targetIconSize * 4)  // RGBA
        
        // 寫入快取
        cache.setObject(resizedIcon, forKey: key, cost: estimatedCost)
        
        lock.lock()
        loadingPaths.remove(path)
        lock.unlock()
        
        return resizedIcon
    }
    
    /// 縮小圖標尺寸（優化版本）
    private func resizeIcon(_ icon: NSImage, to size: CGFloat) -> NSImage {
        let newSize = NSSize(width: size, height: size)
        
        // 直接創建位圖表示，避免中間步驟
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return icon
        }
        
        bitmapRep.size = newSize
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        
        icon.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .copy,
                  fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let finalImage = NSImage(size: newSize)
        finalImage.addRepresentation(bitmapRep)
        return finalImage
    }
    
    /// 非同步獲取應用程式圖示
    func getIconAsync(for path: String, completion: @escaping (NSImage?) -> Void) {
        // 先檢查緩存
        if let cachedIcon = cache.object(forKey: path as NSString) {
            completion(cachedIcon)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let icon = self?.getIcon(for: path)
            DispatchQueue.main.async {
                completion(icon)
            }
        }
    }
    
    /// 清空快取
    func clearCache() {
        cache.removeAllObjects()
        lock.lock()
        loadingPaths.removeAll()
        lock.unlock()
        Logger.debug("AppIconCache cleared")
    }
}
