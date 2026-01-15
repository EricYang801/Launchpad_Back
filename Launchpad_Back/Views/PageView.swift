//
//  PageView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

/// 單個頁面視圖
struct PageView: View {
    let apps: [AppItem]
    let layoutConfig: GridLayoutConfig
    let pageIndex: Int
    let currentPage: Int
    let screenWidth: CGFloat
    let dragAmount: CGSize
    let onAppTap: (AppItem) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            LazyVGrid(columns: layoutConfig.gridColumns, spacing: GridLayoutManager.verticalSpacing) {
                ForEach(apps, id: \.id) { app in
                    AppIconView(app: app) {
                        onAppTap(app)
                    }
                }
            }
            .frame(width: layoutConfig.gridWidth)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(
            x: CGFloat(pageIndex - currentPage) * screenWidth + dragAmount.width,
            y: 0
        )
        .opacity(pageIndex == currentPage ? 1.0 : 0.6)
        .scaleEffect(pageIndex == currentPage ? 1.0 : 0.92)
        .allowsHitTesting(pageIndex == currentPage)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }
}

/// 帶有文件夾支持的頁面視圖
struct PageViewWithFolders: View {
    let items: [LaunchpadDisplayItem]
    let layoutConfig: GridLayoutConfig
    let pageIndex: Int
    let currentPage: Int
    let screenWidth: CGFloat
    let dragAmount: CGSize
    let onAppTap: (AppItem) -> Void
    let onFolderTap: (AppFolder) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            LazyVGrid(columns: layoutConfig.gridColumns, spacing: GridLayoutManager.verticalSpacing) {
                ForEach(items, id: \.id) { item in
                    LaunchpadItemView(
                        item: item,
                        onAppTap: onAppTap,
                        onFolderTap: onFolderTap
                    )
                }
            }
            .frame(width: layoutConfig.gridWidth)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(
            x: CGFloat(pageIndex - currentPage) * screenWidth + dragAmount.width,
            y: 0
        )
        .opacity(pageIndex == currentPage ? 1.0 : 0.6)
        .scaleEffect(pageIndex == currentPage ? 1.0 : 0.92)
        .allowsHitTesting(pageIndex == currentPage)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }
}

#Preview {
    let sampleApps = (0..<10).map { index in
        AppItem(name: "App \(index)", bundleID: "com.app.\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
    }
    let config = GridLayoutConfig(screenSize: CGSize(width: 1200, height: 800))
    
    PageView(
        apps: sampleApps,
        layoutConfig: config,
        pageIndex: 0,
        currentPage: 0,
        screenWidth: 1200,
        dragAmount: .zero,
        onAppTap: { _ in }
    )
}
