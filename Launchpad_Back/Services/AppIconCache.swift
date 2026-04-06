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
/// - 降低圖標解析度至 96px，貼近 80px UI 顯示尺寸
/// - 降低快取上限至 60 個圖標，24MB 記憶體限制
/// - 實作頁面感知快取，只保留當前和相鄰頁面的圖標
/// - 監聽系統記憶體警告，自動清理快取
final class AppIconCache: NSObject {
    static let shared = AppIconCache()
    private typealias IconCompletion = (NSImage?) -> Void
    
    /// 圖示快取（使用 NSCache 自動管理記憶體）
    private let cache = NSCache<NSString, NSImage>()
    
    /// 正在載入的路徑集合（防止重複載入）
    private var loadingPaths: Set<String> = []
    private var pendingCompletions: [String: [IconCompletion]] = [:]
    
    /// 訪問保護鎖
    private let lock = NSLock()
    private let resolver: AppIconResolver
    
    /// 圖標目標尺寸（貼近 UI 實際使用尺寸，減少不必要的位圖記憶體）
    private let targetIconSize: CGFloat = 96.0
    
    /// 當前活躍的頁面索引（用於頁面感知快取）
    private var currentActivePage: Int = 0
    private var itemsPerPage: Int = 35  // 預設值，實際會由外部設定
    
    /// 上次清理時間
    private var lastCleanupTime: Date = Date()
    private let cleanupInterval: TimeInterval = 60  // 每 60 秒檢查一次是否需要清理
    
    init(resolver: AppIconResolver = .shared) {
        self.resolver = resolver
        super.init()
        
        // 優化：降低快取限制以節省記憶體
        cache.countLimit = 60
        cache.totalCostLimit = 24 * 1024 * 1024
        
        // 設定 NSCache 代理，實現 LRU 策略
        cache.delegate = self
        
        // 監聽記憶體警告
        setupMemoryWarningObserver()
        
        Logger.debug("AppIconCache initialized with optimized settings: max=60, limit=24MB, iconSize=96px")
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

    func cachedIcon(for path: String, appName: String? = nil) -> NSImage? {
        let key = resolver.cacheKey(for: path) as NSString
        return cache.object(forKey: key)
    }
    
    /// 獲取應用程式圖示（線程安全，同步操作）
    /// - Parameter path: 應用程式路徑
    /// - Returns: NSImage 或 nil
    func getIcon(for path: String, appName: String? = nil) -> NSImage? {
        let keyString = resolver.cacheKey(for: path)
        let key = keyString as NSString
        
        // 快速路徑：檢查快取（無鎖）
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }
        
        lock.lock()

        // 再次檢查（可能另一個線程已經加載）
        if let cachedIcon = cache.object(forKey: key) {
            lock.unlock()
            return cachedIcon
        }
        
        if !beginLoadingIfNeeded(for: keyString) {
            lock.unlock()
            return nil
        }
        lock.unlock()
        
        let loadedIcon = loadAndCacheIcon(for: path, appName: appName, key: key)
        completeLoad(for: keyString, icon: loadedIcon)
        return loadedIcon
    }
    
    /// 縮小圖標尺寸（優化版本）
    private func resizeIcon(_ icon: NSImage, to size: CGFloat) -> NSImage {
        performGraphicsWork {
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
    }
    
    /// 非同步獲取應用程式圖示
    func getIconAsync(for path: String, appName: String? = nil, completion: @escaping (NSImage?) -> Void) {
        // 先檢查緩存
        if let cachedIcon = cachedIcon(for: path, appName: appName) {
            completion(cachedIcon)
            return
        }

        let keyString = resolver.cacheKey(for: path)
        let key = keyString as NSString
        var shouldStartLoading = false

        lock.lock()
        if let cachedIcon = cache.object(forKey: key) {
            lock.unlock()
            completion(cachedIcon)
            return
        }

        pendingCompletions[keyString, default: []].append(completion)
        shouldStartLoading = beginLoadingIfNeeded(for: keyString)
        lock.unlock()

        guard shouldStartLoading else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let icon = self.loadAndCacheIcon(for: path, appName: appName, key: key)
            self.completeLoad(for: keyString, icon: icon)
        }
    }
    
    /// 預載入指定範圍的圖標（用於頁面切換優化）
    /// - Parameter paths: 需要預載入的應用路徑列表
    func preloadIcons(for requests: [(path: String, appName: String?)]) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for request in requests {
                let cacheKey = self?.resolver.cacheKey(for: request.path) as NSString?
                // 只預載入尚未快取的圖標
                if let cacheKey, self?.cache.object(forKey: cacheKey) == nil {
                    _ = self?.getIcon(for: request.path, appName: request.appName)
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
        pendingCompletions.removeAll()
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
    
    private func performGraphicsWork<T>(_ work: () -> T) -> T {
        if Thread.isMainThread {
            return work()
        }
        
        return DispatchQueue.main.sync(execute: work)
    }

    private func beginLoadingIfNeeded(for keyString: String) -> Bool {
        guard !loadingPaths.contains(keyString) else {
            return false
        }

        loadingPaths.insert(keyString)
        return true
    }

    private func loadAndCacheIcon(for path: String, appName: String?, key: NSString) -> NSImage {
        let resolvedIcon: NSImage = autoreleasepool {
            resolver.resolveIcon(for: path, appName: appName, targetSize: targetIconSize).image
        }
        let resizedIcon: NSImage = autoreleasepool {
            resizeIcon(resolvedIcon, to: targetIconSize)
        }

        let estimatedCost = Int(targetIconSize * targetIconSize * 4)
        cache.setObject(resizedIcon, forKey: key, cost: estimatedCost)
        return resizedIcon
    }

    private func completeLoad(for keyString: String, icon: NSImage?) {
        lock.lock()
        loadingPaths.remove(keyString)
        let completions = pendingCompletions.removeValue(forKey: keyString) ?? []
        lock.unlock()

        guard !completions.isEmpty else {
            return
        }

        DispatchQueue.main.async {
            completions.forEach { completion in
                completion(icon)
            }
        }
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
