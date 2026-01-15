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
    let columns: [GridItem]
    let pageIndex: Int
    let currentPage: Int
    let screenWidth: CGFloat
    let dragAmount: CGSize
    let onAppTap: (AppItem) -> Void
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(apps, id: \.id) { app in
                AppIconView(app: app) {
                    onAppTap(app)
                }
            }
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
        .offset(
            x: CGFloat(pageIndex - currentPage) * screenWidth + dragAmount.width,
            y: 0
        )
        .opacity(pageIndex == currentPage ? 1.0 : 0.8)
        .scaleEffect(pageIndex == currentPage ? 1.0 : 0.95)
        .allowsHitTesting(pageIndex == currentPage)
    }
}

#Preview {
    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    let sampleApps = (0..<10).map { index in
        AppItem(name: "App \(index)", bundleID: "com.app.\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
    }
    
    PageView(
        apps: sampleApps,
        columns: gridColumns,
        pageIndex: 0,
        currentPage: 0,
        screenWidth: 1200,
        dragAmount: .zero,
        onAppTap: { _ in }
    )
}
