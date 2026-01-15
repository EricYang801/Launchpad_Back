//
//  GridLayoutManager.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

/// 網格布局管理器
/// 負責計算 Launchpad 的網格布局參數
struct GridLayoutManager {
    // MARK: - 布局常數（類似原版 Launchpad）
    
    /// 圖示大小
    static let iconSize: CGFloat = 80
    
    /// 圖示標籤最大寬度
    static let labelMaxWidth: CGFloat = 90
    
    /// 圖示標籤高度
    static let labelHeight: CGFloat = 36
    
    /// 項目總高度（圖示 + 間距 + 標籤）
    static let itemHeight: CGFloat = iconSize + 8 + labelHeight
    
    /// 項目總寬度
    static let itemWidth: CGFloat = labelMaxWidth
    
    /// 水平間距
    static let horizontalSpacing: CGFloat = 36
    
    /// 垂直間距
    static let verticalSpacing: CGFloat = 28
    
    /// 頂部邊距（搜索欄下方）
    static let topPadding: CGFloat = 10
    
    /// 底部邊距（頁面指示器上方）
    static let bottomPadding: CGFloat = 30
    
    /// 左右邊距
    static let horizontalPadding: CGFloat = 20
    
    // MARK: - 計算屬性
    
    /// 計算每行的列數
    /// - Parameter screenWidth: 螢幕寬度
    /// - Returns: 列數
    static func columns(for screenWidth: CGFloat) -> Int {
        let availableWidth = screenWidth - (horizontalPadding * 2)
        let itemTotalWidth = itemWidth + horizontalSpacing
        let cols = Int(availableWidth / itemTotalWidth)
        return max(5, min(cols, 9)) // 限制在 5-9 列之間
    }
    
    /// 計算每頁的行數
    /// - Parameter screenHeight: 螢幕高度
    /// - Returns: 行數
    static func rows(for screenHeight: CGFloat) -> Int {
        let availableHeight = screenHeight - topPadding - bottomPadding - 80 // 80 for search bar area
        let itemTotalHeight = itemHeight + verticalSpacing
        let rows = Int(availableHeight / itemTotalHeight)
        return max(3, min(rows, 7)) // 限制在 3-7 行之間
    }
    
    /// 計算每頁的應用數量
    /// - Parameters:
    ///   - screenWidth: 螢幕寬度
    ///   - screenHeight: 螢幕高度
    /// - Returns: 每頁應用數量
    static func appsPerPage(screenWidth: CGFloat, screenHeight: CGFloat) -> Int {
        columns(for: screenWidth) * rows(for: screenHeight)
    }
    
    /// 生成網格列定義
    /// - Parameter count: 列數
    /// - Returns: GridItem 陣列
    static func gridColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.fixed(itemWidth), spacing: horizontalSpacing), count: count)
    }
    
    /// 計算網格實際寬度
    /// - Parameter columnCount: 列數
    /// - Returns: 網格寬度
    static func gridWidth(columnCount: Int) -> CGFloat {
        CGFloat(columnCount) * itemWidth + CGFloat(columnCount - 1) * horizontalSpacing
    }
    
    /// 計算網格實際高度
    /// - Parameter rowCount: 行數
    /// - Returns: 網格高度
    static func gridHeight(rowCount: Int) -> CGFloat {
        CGFloat(rowCount) * itemHeight + CGFloat(rowCount - 1) * verticalSpacing
    }
}

/// 網格布局配置結構
struct GridLayoutConfig {
    let columns: Int
    let rows: Int
    let itemsPerPage: Int
    let gridColumns: [GridItem]
    let gridWidth: CGFloat
    let gridHeight: CGFloat
    
    init(screenSize: CGSize) {
        self.columns = GridLayoutManager.columns(for: screenSize.width)
        self.rows = GridLayoutManager.rows(for: screenSize.height)
        self.itemsPerPage = columns * rows
        self.gridColumns = GridLayoutManager.gridColumns(count: columns)
        self.gridWidth = GridLayoutManager.gridWidth(columnCount: columns)
        self.gridHeight = GridLayoutManager.gridHeight(rowCount: rows)
    }
}
