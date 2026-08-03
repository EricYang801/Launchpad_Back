//
//  SearchBarView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

/// 搜尋欄 UI 組件（類似原版 Launchpad）
struct SearchBarView: View {
    @Binding var text: String
    /// 由外部（LaunchpadView）控制的焦點，讓「打字即搜尋」可以隨時把焦點導回搜尋欄
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            TextField("搜尋", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused(isFocused)
                .tint(.white)
            
            if !text.isEmpty {
                Button(action: { 
                    withAnimation(.easeOut(duration: 0.15)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

#if DEBUG
private struct SearchBarPreviewContainer: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black
            SearchBarView(text: $text, isFocused: $isFocused)
        }
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarPreviewContainer()
    }
}
#endif
