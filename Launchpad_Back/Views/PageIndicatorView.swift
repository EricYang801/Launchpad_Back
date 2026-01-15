//
//  PageIndicatorView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

/// 頁面指示器視圖（類似原版 Launchpad）
struct PageIndicatorView: View {
    let currentPage: Int
    let totalPages: Int
    let onPageTap: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    .onTapGesture {
                        onPageTap(index)
                    }
                    .contentShape(Circle().scale(2)) // 增大點擊區域
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

#Preview {
    ZStack {
        Color.black
        PageIndicatorView(currentPage: 0, totalPages: 5) { _ in }
    }
}
