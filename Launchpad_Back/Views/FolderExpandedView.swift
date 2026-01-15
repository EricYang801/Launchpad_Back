//
//  FolderExpandedView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import UniformTypeIdentifiers

/// 展開的文件夾視圖
struct FolderExpandedView: View {
    let folder: AppFolder
    let onAppTap: (AppItem) -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void
    let onReorder: (Int, Int) -> Void  // 新增：重新排序回調
    
    @State private var folderName: String
    @State private var isEditingName = false
    @State private var draggingApp: AppItem?
    @FocusState private var isNameFieldFocused: Bool
    
    init(folder: AppFolder, 
         onAppTap: @escaping (AppItem) -> Void, 
         onClose: @escaping () -> Void, 
         onRename: @escaping (String) -> Void,
         onReorder: @escaping (Int, Int) -> Void = { _, _ in }) {
        self.folder = folder
        self.onAppTap = onAppTap
        self.onClose = onClose
        self.onRename = onRename
        self.onReorder = onReorder
        self._folderName = State(initialValue: folder.name)
    }
    
    // 根據應用數量動態調整列數
    private var columnCount: Int {
        min(max(folder.apps.count, 2), 4)
    }
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(GridLayoutManager.itemWidth), spacing: GridLayoutManager.horizontalSpacing), count: columnCount)
    }
    
    // 動態計算視圖寬度
    private var contentWidth: CGFloat {
        let itemsWidth = CGFloat(columnCount) * GridLayoutManager.itemWidth
        let spacingWidth = CGFloat(columnCount - 1) * GridLayoutManager.horizontalSpacing
        return itemsWidth + spacingWidth + 48  // 48 = padding
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onClose()
                    }
                
                // 文件夾內容 - 居中顯示
                VStack(spacing: 16) {
                    // 文件夾名稱（可編輯）
                    folderNameView
                    
                    // 分隔線
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                    
                    // 應用程式網格
                    LazyVGrid(columns: columns, spacing: GridLayoutManager.verticalSpacing) {
                        ForEach(Array(folder.apps.enumerated()), id: \.element.id) { index, app in
                            AppIconView(app: app) {
                                onAppTap(app)
                            }
                            .opacity(draggingApp?.id == app.id ? 0.5 : 1.0)
                            .onDrag {
                                self.draggingApp = app
                                return NSItemProvider(object: app.bundleID as NSString)
                            }
                            .onDrop(of: [.text], delegate: FolderDropDelegate(
                                item: app,
                                items: folder.apps,
                                draggingItem: $draggingApp,
                                onReorder: onReorder
                            ))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .padding(.vertical, 20)
                .frame(width: contentWidth)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private var folderNameView: some View {
        Group {
            if isEditingName {
                TextField("Folder Name", text: $folderName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        isEditingName = false
                        if !folderName.isEmpty {
                            onRename(folderName)
                        }
                    }
                    .onAppear {
                        isNameFieldFocused = true
                    }
            } else {
                Text(folderName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .onTapGesture {
                        isEditingName = true
                    }
            }
        }
        .padding(.horizontal, 20)
    }
}

// 文件夾內拖放代理
struct FolderDropDelegate: DropDelegate {
    let item: AppItem
    let items: [AppItem]
    @Binding var draggingItem: AppItem?
    let onReorder: (Int, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        onReorder(fromIndex, toIndex)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

#Preview {
    let sampleApps = (0..<6).map { index in
        AppItem(name: "App \(index)", bundleID: "com.app.\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
    }
    let folder = AppFolder(name: "Utilities", apps: sampleApps)
    
    return FolderExpandedView(
        folder: folder,
        onAppTap: { _ in },
        onClose: {},
        onRename: { _ in },
        onReorder: { _, _ in }
    )
}
