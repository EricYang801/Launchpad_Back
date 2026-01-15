//
//  PaginationViewModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import Combine

/// 分頁管理的 ViewModel
/// 負責頁面導航和分頁邏輯
class PaginationViewModel: ObservableObject {
    @Published var currentPage = 0
    @Published private(set) var screenSize: CGSize = .zero
    
    /// 尺寸變化的最小閾值（避免微小變化觸發重算）
    private let sizeChangeThreshold: CGFloat = 10.0
    
    /// 緩存的佈局配置
    private var cachedLayoutConfig: GridLayoutConfig?
    
    /// 當前布局配置（使用緩存提高效能）
    var layoutConfig: GridLayoutConfig {
        if let cached = cachedLayoutConfig {
            return cached
        }
        let config = GridLayoutConfig(screenSize: screenSize)
        cachedLayoutConfig = config
        return config
    }
    
    /// 每頁應用數量（根據螢幕大小動態計算）
    var appsPerPage: Int {
        layoutConfig.itemsPerPage
    }
    
    /// 更新螢幕尺寸（帶有閾值檢查以避免頻繁更新）
    func updateScreenSize(_ size: CGSize) {
        // 檢查尺寸變化是否超過閾值
        let widthChange = abs(screenSize.width - size.width)
        let heightChange = abs(screenSize.height - size.height)
        
        guard widthChange > sizeChangeThreshold || heightChange > sizeChangeThreshold else {
            return
        }
        
        screenSize = size
        cachedLayoutConfig = nil  // 清除緩存，下次訪問時重新計算
        Logger.debug("Screen size updated to \(size.width)x\(size.height)")
    }
    
    /// 計算總頁數
    /// - Parameter itemCount: 項目總數
    /// - Returns: 總頁數
    func totalPages(for itemCount: Int) -> Int {
        guard appsPerPage > 0 else { return 1 }
        return max(1, Int(ceil(Double(itemCount) / Double(appsPerPage))))
    }
    
    /// 獲取指定頁面的應用程式
    /// - Parameters:
    ///   - apps: 應用程式陣列
    ///   - page: 頁面索引
    /// - Returns: 該頁面的應用程式
    func appsForPage(_ apps: [AppItem], page: Int) -> [AppItem] {
        let startIndex = page * appsPerPage
        let endIndex = min(startIndex + appsPerPage, apps.count)
        
        guard startIndex < apps.count else { return [] }
        return Array(apps[startIndex..<endIndex])
    }
    
    /// 獲取指定頁面的項目（支持文件夾）
    func itemsForPage(_ items: [LaunchpadDisplayItem], page: Int) -> [LaunchpadDisplayItem] {
        let startIndex = page * appsPerPage
        let endIndex = min(startIndex + appsPerPage, items.count)
        
        guard startIndex < items.count else { return [] }
        return Array(items[startIndex..<endIndex])
    }
    
    /// 上一頁
    func previousPage() {
        if currentPage > 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentPage -= 1
            }
        }
    }
    
    /// 下一頁
    func nextPage(totalPages: Int) {
        if currentPage < totalPages - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentPage += 1
            }
        }
    }
    
    /// 跳轉到指定頁面
    /// - Parameters:
    ///   - page: 目標頁面
    ///   - totalPages: 總頁數
    func jumpToPage(_ page: Int, totalPages: Int) {
        let validPage = max(0, min(page, totalPages - 1))
        guard validPage != currentPage else { return }  // 避免無意義的更新
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentPage = validPage
        }
    }
    
    /// 重置到第一頁
    func reset() {
        guard currentPage != 0 else { return }  // 避免無意義的更新
        currentPage = 0
    }
    
    /// 確保當前頁面有效
    func validateCurrentPage(totalPages: Int) {
        if currentPage >= totalPages {
            currentPage = max(0, totalPages - 1)
        }
    }
}
