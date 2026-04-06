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
/// - 降低快取上限至 48 個圖標，16MB 記憶體限制
/// - 合併重複請求，避免同一路徑重複解碼
/// - 使用共享背景載入佇列，減少大量短命工作項造成的排程成本
final class AppIconCache {
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
    private let loadQueue = DispatchQueue(
        label: "com.launchpad.icon-cache.load",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    /// 圖標目標尺寸（貼近 UI 實際使用尺寸，減少不必要的位圖記憶體）
    private let targetIconSize: CGFloat = 96.0
    
    init(resolver: AppIconResolver = .shared) {
        self.resolver = resolver
        
        cache.countLimit = 48
        cache.totalCostLimit = 16 * 1024 * 1024
        
        Logger.debug("AppIconCache initialized with optimized settings: max=48, limit=16MB, iconSize=96px")
    }
    
    // MARK: - 圖標獲取

    func cachedIcon(for path: String) -> NSImage? {
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
        if let cachedIcon = cachedIcon(for: path) {
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
        
        loadQueue.async { [weak self] in
            guard let self else { return }
            let icon = self.loadAndCacheIcon(for: path, appName: appName, key: key)
            self.completeLoad(for: keyString, icon: icon)
        }
    }
    
    /// 預載入指定範圍的圖標（用於頁面切換優化）
    /// - Parameter paths: 需要預載入的應用路徑列表
    func preloadIcons(for requests: [(path: String, appName: String?)]) {
        guard !requests.isEmpty else { return }
        
        let uniqueRequests = Dictionary(grouping: requests, by: { resolver.cacheKey(for: $0.path) })
            .compactMap { $0.value.first }
        
        loadQueue.async { [weak self] in
            for request in uniqueRequests {
                autoreleasepool {
                    guard let self else { return }
                    if self.cachedIcon(for: request.path) == nil {
                        _ = self.getIcon(for: request.path, appName: request.appName)
                    }
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
