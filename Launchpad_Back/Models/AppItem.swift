//
//  AppItem.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// 表示 macOS 應用程式的數據模型
struct AppItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let path: String
    let isSystemApp: Bool
    
    /// 獲取應用程式圖示（會使用快取）
    var appIcon: NSImage? {
        AppIconCache.shared.getIcon(for: path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
