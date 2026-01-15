//
//  AppItem.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import AppKit

/// Launchpad 項目類型協議
protocol LaunchpadItem: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var displayOrder: Int { get set }
}

/// 表示 macOS 應用程式的數據模型
struct AppItem: LaunchpadItem {
    let id: UUID
    let name: String
    let bundleID: String
    let path: String
    let isSystemApp: Bool
    var displayOrder: Int = 0
    
    /// 初始化應用程式項目
    /// - Parameters:
    ///   - id: 唯一識別碼（默認自動生成，用於持久化時可指定）
    ///   - name: 應用程式名稱
    ///   - bundleID: Bundle 識別碼
    ///   - path: 應用程式路徑
    ///   - isSystemApp: 是否為系統應用
    ///   - displayOrder: 顯示順序
    init(
        id: UUID = UUID(),
        name: String,
        bundleID: String,
        path: String,
        isSystemApp: Bool,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.isSystemApp = isSystemApp
        self.displayOrder = displayOrder
    }
    
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

/// 表示應用程式文件夾的數據模型
struct AppFolder: LaunchpadItem {
    let id: UUID
    var name: String
    var apps: [AppItem]
    var displayOrder: Int = 0
    var isExpanded: Bool = false
    
    init(id: UUID = UUID(), name: String, apps: [AppItem], displayOrder: Int = 0) {
        self.id = id
        self.name = name
        self.apps = apps
        self.displayOrder = displayOrder
    }
    
    /// 文件夾中應用數量
    var appCount: Int {
        apps.count
    }
    
    /// 獲取文件夾預覽圖示（最多顯示 9 個應用圖示）
    var previewIcons: [NSImage?] {
        Array(apps.prefix(9)).map { $0.appIcon }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppFolder, rhs: AppFolder) -> Bool {
        lhs.id == rhs.id
    }
    
    /// 添加應用到文件夾
    mutating func addApp(_ app: AppItem) {
        if !apps.contains(where: { $0.bundleID == app.bundleID }) {
            apps.append(app)
        }
    }
    
    /// 從文件夾移除應用
    mutating func removeApp(_ app: AppItem) {
        apps.removeAll { $0.bundleID == app.bundleID }
    }
}

/// Launchpad 中可顯示的項目（可以是應用或文件夾）
enum LaunchpadDisplayItem: Identifiable, Hashable {
    case app(AppItem)
    case folder(AppFolder)
    
    var id: UUID {
        switch self {
        case .app(let app): return app.id
        case .folder(let folder): return folder.id
        }
    }
    
    var name: String {
        switch self {
        case .app(let app): return app.name
        case .folder(let folder): return folder.name
        }
    }
    
    var displayOrder: Int {
        get {
            switch self {
            case .app(let app): return app.displayOrder
            case .folder(let folder): return folder.displayOrder
            }
        }
        set {
            switch self {
            case .app(var app):
                app.displayOrder = newValue
                self = .app(app)
            case .folder(var folder):
                folder.displayOrder = newValue
                self = .folder(folder)
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
