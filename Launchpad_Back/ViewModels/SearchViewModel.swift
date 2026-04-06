//
//  SearchViewModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import Combine

/// 搜尋功能的 ViewModel
/// 負責搜尋文本狀態
final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    
    /// 清除搜尋
    func clearSearch() {
        searchText = ""
    }
}
