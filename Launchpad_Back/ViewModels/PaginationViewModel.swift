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
    
    private let appsPerPage: Int
    
    init(appsPerPage: Int = 35) {
        self.appsPerPage = appsPerPage
    }
    
    /// 計算總頁數
    /// - Parameter itemCount: 項目總數
    /// - Returns: 總頁數
    func totalPages(for itemCount: Int) -> Int {
        max(1, Int(ceil(Double(itemCount) / Double(appsPerPage))))
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
    
    /// 上一頁
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }
    
    /// 下一頁
    func nextPage(totalPages: Int) {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }
    
    /// 跳轉到指定頁面
    /// - Parameters:
    ///   - page: 目標頁面
    ///   - totalPages: 總頁數
    func jumpToPage(_ page: Int, totalPages: Int) {
        let validPage = max(0, min(page, totalPages - 1))
        currentPage = validPage
    }
    
    /// 重置到第一頁
    func reset() {
        currentPage = 0
    }
}
