//
//  LiquidGlassComponents.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI

// MARK: - Liquid Glass Background
struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            // 背景漸層
            LinearGradient(
                colors: [
                    Color.white.opacity(0.4),
                    Color.white.opacity(0.1),
                    Color.black.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 玻璃材質效果
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
            
            // 光澤反射效果
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.clear,
                    Color.white.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)
        }
    }
}

// MARK: - App Icon Card
struct AppIconCard: View {
    let app: AppItem
    let isSelected: Bool
    @State private var isHovered: Bool = false
    @State private var isPressing: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖示容器
            ZStack {
                // 背景玻璃面板
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: isHovered ? 12 : 6,
                        x: 0,
                        y: isHovered ? 6 : 3
                    )
                
                // 內光暈效果
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.3 : 0.1),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .blendMode(.softLight)
                
                // 應用圖示
                if let appIcon = app.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(
                            color: .white.opacity(0.5),
                            radius: 1,
                            x: 0,
                            y: 1
                        )
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .primary,
                                    .primary.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: .white.opacity(0.5),
                            radius: 1,
                            x: 0,
                            y: 1
                        )
                }
            }
            .frame(width: 64, height: 64)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .scaleEffect(isPressing ? 0.95 : 1.0)
            
            // 應用名稱
            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 80, height: 90)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressing)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressing = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressing = false
                }
            }
        }
    }
}

// MARK: - Search Bar
struct LiquidGlassSearchBar: View {
    @Binding var searchText: String
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("搜尋應用程式", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            ZStack {
                // 玻璃背景
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                // 邊框高光
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // 內光暈
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.softLight)
            }
        }
        .shadow(
            color: .black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Page Indicator (舊版本 - 已棄用)
struct LegacyPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    let onPageTap: ((Int) -> Void)?
    
    init(currentPage: Int, totalPages: Int, onPageTap: ((Int) -> Void)? = nil) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.onPageTap = onPageTap
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { page in
                Circle()
                    .fill(
                        page == currentPage
                            ? Color.primary.opacity(0.8)
                            : Color.primary.opacity(0.3)
                    )
                    .frame(width: 6, height: 6)
                    .scaleEffect(page == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    .onTapGesture {
                        onPageTap?(page)
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .shadow(
            color: .black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}
