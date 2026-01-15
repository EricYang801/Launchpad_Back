//
//  PageIndicatorView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

/// 頁面指示器視圖
struct PageIndicatorView: View {
    let currentPage: Int
    let totalPages: Int
    let onPageTap: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        onPageTap(index)
                    }
                    .transition(.scale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: Capsule())
    }
}

#Preview {
    PageIndicatorView(currentPage: 0, totalPages: 5) { _ in }
}
