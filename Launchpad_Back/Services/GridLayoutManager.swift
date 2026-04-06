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
    static let minimumColumns = 5
    static let maximumColumns = 9
    static let minimumRows = 3
    static let maximumRows = 7
    static let minimumWindowColumns = 6
    static let minimumWindowRows = 4
    
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
    
    /// 頂部保留區（搜尋列與上方留白）
    static let headerAreaHeight: CGFloat = 64
    
    /// 底部保留區（頁面指示器與下方留白）
    static let footerAreaHeight: CGFloat = 44
    
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
        return max(minimumColumns, min(cols, maximumColumns))
    }
    
    /// 計算每頁的行數
    /// - Parameter screenHeight: 螢幕高度
    /// - Returns: 行數
    static func rows(for screenHeight: CGFloat) -> Int {
        let availableHeight = screenHeight - headerAreaHeight - footerAreaHeight
        let itemTotalHeight = itemHeight + verticalSpacing
        let rows = Int(availableHeight / itemTotalHeight)
        return max(minimumRows, min(rows, maximumRows))
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

    static func contentSize(columnCount: Int, rowCount: Int) -> CGSize {
        CGSize(
            width: gridWidth(columnCount: columnCount) + (horizontalPadding * 2),
            height: gridHeight(rowCount: rowCount) + headerAreaHeight + footerAreaHeight
        )
    }

    static var minimumWindowContentSize: CGSize {
        contentSize(columnCount: minimumWindowColumns, rowCount: minimumWindowRows)
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
