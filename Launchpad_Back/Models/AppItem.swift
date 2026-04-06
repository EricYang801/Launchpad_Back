//
//  AppItem.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import Foundation

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
    /// 用於持久化與去重的穩定識別鍵。
    /// 某些 App 沒有 bundle ID，此時退回使用安裝路徑。
    var stableIdentifier: String {
        bundleID.isEmpty ? path : bundleID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stableIdentifier)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.stableIdentifier == rhs.stableIdentifier
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
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppFolder, rhs: AppFolder) -> Bool {
        lhs.id == rhs.id
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

    var persistenceKey: String {
        switch self {
        case .app(let app):
            return "app:\(app.stableIdentifier)"
        case .folder(let folder):
            return "folder:\(folder.id.uuidString)"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
