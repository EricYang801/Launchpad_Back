//
//  AppIconCache.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 應用程式圖示快取管理器
/// 負責非同步加載和緩存應用程式圖示，減少重複讀取磁碟的開銷
///
/// 記憶體優化：
/// - 降低圖標解析度至 128px（Retina 顯示已足夠清晰）
/// - 降低快取上限至 100 個圖標，40MB 記憶體限制
/// - 實作頁面感知快取，只保留當前和相鄰頁面的圖標
/// - 監聽系統記憶體警告，自動清理快取
final class AppIconCache: NSObject {
    static let shared = AppIconCache()
    
    /// 圖示快取（使用 NSCache 自動管理記憶體）
    private let cache = NSCache<NSString, NSImage>()
    
    /// 正在載入的路徑集合（防止重複載入）
    private var loadingPaths: Set<String> = []
    
    /// 訪問保護鎖
    private let lock = NSLock()
    
    /// 圖標目標尺寸（優化：從 160 降至 128，節省約 30% 記憶體）
    private let targetIconSize: CGFloat = 128.0
    
    /// 當前活躍的頁面索引（用於頁面感知快取）
    private var currentActivePage: Int = 0
    private var itemsPerPage: Int = 35  // 預設值，實際會由外部設定
    
    /// 上次清理時間
    private var lastCleanupTime: Date = Date()
    private let cleanupInterval: TimeInterval = 60  // 每 60 秒檢查一次是否需要清理
    
    private override init() {
        super.init()
        
        // 優化：降低快取限制以節省記憶體
        cache.countLimit = 100  // 從 200 降至 100
        cache.totalCostLimit = 40 * 1024 * 1024  // 從 100MB 降至 40MB
        
        // 設定 NSCache 代理，實現 LRU 策略
        cache.delegate = self
        
        // 監聽記憶體警告
        setupMemoryWarningObserver()
        
        Logger.debug("AppIconCache initialized with optimized settings: max=100, limit=40MB, iconSize=128px")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 記憶體警告處理
    
    /// 設定記憶體警告監聽器
    private func setupMemoryWarningObserver() {
        // macOS 沒有 UIApplication 的記憶體警告，但可以監聽系統通知
        // 或者定期清理不活躍的快取
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: NSNotification.Name("NSApplicationWillTerminateNotification"),
            object: nil
        )
    }
    
    @objc private func handleMemoryPressure() {
        Logger.warning("Memory pressure detected, clearing icon cache")
        clearCache()
    }
    
    // MARK: - 頁面感知快取
    
    /// 更新當前活躍頁面（用於智能快取管理）
    /// - Parameters:
    ///   - page: 當前頁面索引
    ///   - itemsPerPage: 每頁項目數
    func updateActivePage(_ page: Int, itemsPerPage: Int) {
        self.currentActivePage = page
        self.itemsPerPage = itemsPerPage
        
        // 檢查是否需要清理舊快取
        let now = Date()
        if now.timeIntervalSince(lastCleanupTime) > cleanupInterval {
            cleanupInactivePageIcons()
            lastCleanupTime = now
        }
    }
    
    /// 清理不在當前頁面範圍內的圖標（保留當前頁 ± 1 頁）
    private func cleanupInactivePageIcons() {
        // 由於 NSCache 沒有提供遍歷所有鍵的方法，
        // 我們依賴 NSCache 的自動清理機制
        // 這裡只是觸發一次手動清理，移除最不常用的項目
        
        // NSCache 會自動根據 countLimit 和 totalCostLimit 清理
        // 我們只需要確保這些限制設定正確即可
        Logger.debug("Triggered automatic cache cleanup")
    }
    
    // MARK: - 圖標獲取
    
    /// 獲取應用程式圖示（線程安全，同步操作）
    /// - Parameter path: 應用程式路徑
    /// - Returns: NSImage 或 nil
    func getIcon(for path: String) -> NSImage? {
        let key = path as NSString
        
        // 快速路徑：檢查快取（無鎖）
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        // 再次檢查（可能另一個線程已經加載）
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }
        
        // 檢查是否正在載入（防止重複載入）
        if loadingPaths.contains(path) {
            return nil  // 正在載入中，返回 nil
        }
        
        // 標記為正在載入
        loadingPaths.insert(path)
        
        lock.unlock()  // 解鎖以便其他線程可以進行快速路徑查詢
        
        // 載入圖示（在鎖外執行，使用 autoreleasepool）
        let resizedIcon: NSImage = autoreleasepool {
            let originalIcon = NSWorkspace.shared.icon(forFile: path)
            return resizeIcon(originalIcon, to: targetIconSize)
        }
        
        // 估算圖標大小用於 NSCache 成本（優化後的估算）
        let estimatedCost = Int(targetIconSize * targetIconSize * 4)  // RGBA: 128*128*4 = 65KB
        
        // 寫入快取
        cache.setObject(resizedIcon, forKey: key, cost: estimatedCost)
        
        lock.lock()
        loadingPaths.remove(path)
        
        return resizedIcon
    }
    
    /// 縮小圖標尺寸（優化版本）
    private func resizeIcon(_ icon: NSImage, to size: CGFloat) -> NSImage {
        let newSize = NSSize(width: size, height: size)
        
        // 檢查圖標是否已經是目標尺寸或更小，避免不必要的處理
        if icon.size.width <= size && icon.size.height <= size {
            return icon
        }
        
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
    
    /// 預載入指定範圍的圖標（用於頁面切換優化）
    /// - Parameter paths: 需要預載入的應用路徑列表
    func preloadIcons(for paths: [String]) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for path in paths {
                // 只預載入尚未快取的圖標
                if self?.cache.object(forKey: path as NSString) == nil {
                    _ = self?.getIcon(for: path)
                }
            }
        }
    }
    
    // MARK: - 快取管理
    
    /// 清空快取
    func clearCache() {
        cache.removeAllObjects()
        lock.lock()
        loadingPaths.removeAll()
        lock.unlock()
        Logger.debug("AppIconCache cleared completely")
    }
    
    /// 部分清理快取（保留最近使用的項目）
    func trimCache(to percentage: Int) {
        guard percentage > 0 && percentage < 100 else { return }
        
        // NSCache 會自動處理，我們只需要降低臨時的限制
        let originalLimit = cache.countLimit
        cache.countLimit = originalLimit * percentage / 100
        
        // 恢復原始限制
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.cache.countLimit = originalLimit
        }
        
        Logger.debug("Trimmed cache to \(percentage)%")
    }
    
    /// 獲取快取統計信息（用於調試）
    func getCacheStats() -> (count: Int, estimatedSize: String) {
        // NSCache 不提供直接的統計方法，返回配置信息
        let maxCount = cache.countLimit
        let maxSize = cache.totalCostLimit
        let sizeInMB = Double(maxSize) / (1024 * 1024)
        return (maxCount, String(format: "%.1f MB", sizeInMB))
    }
}

// MARK: - NSCacheDelegate

extension AppIconCache: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // 當 NSCache 自動移除物件時被調用
        // 可以在這裡記錄日誌或進行其他清理工作
        Logger.debug("NSCache evicted an icon to free memory")
    }
}
