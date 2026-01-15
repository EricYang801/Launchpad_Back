//
//  SearchViewModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import Combine

/// 搜尋功能的 ViewModel
/// 負責搜尋文本和篩選應用程式
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var currentPage = 0
    
    /// 根據搜尋文本篩選應用程式
    /// - Parameters:
    ///   - apps: 原始應用程式列表
    ///   - searchText: 搜尋文本
    /// - Returns: 篩選後的應用程式
    func filterApps(_ apps: [AppItem], by searchText: String) -> [AppItem] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return apps
        }
        
        let query = searchText.lowercased()
        return apps.filter { app in
            app.name.lowercased().contains(query) ||
            app.bundleID.lowercased().contains(query)
        }
    }
    
    /// 清除搜尋
    func clearSearch() {
        searchText = ""
        currentPage = 0
    }
    
    /// 重置搜尋頁面
    func resetPage() {
        currentPage = 0
    }
}
