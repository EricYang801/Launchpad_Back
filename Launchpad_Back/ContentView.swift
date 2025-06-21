//
//  ContentView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 6/21/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LaunchpadViewModel()
    
    var body: some View {
        LaunchpadView()
            .environmentObject(viewModel)
    }
}

struct LaunchpadView: View {
    @EnvironmentObject var viewModel: LaunchpadViewModel
    @State private var currentPage = 0
    @State private var dragAmount = CGSize.zero
    @State private var searchText = ""
    @State private var scrollMonitor: Any? // 用於存儲事件監聽器
    @State private var scrollGestureInProgress = false
    @State private var gestureResetTimer: Timer?
    
    // 配置
    private let appsPerPage = 35
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    
    // 計算屬性
    private var filteredApps: [AppItem] {
        let uniqueApps = Dictionary(grouping: viewModel.apps, by: \.bundleID)
            .compactMapValues { $0.first }
            .values
            .sorted { $0.name < $1.name }
        
        if searchText.isEmpty {
            return Array(uniqueApps)
        }
        return uniqueApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredApps.count) / Double(appsPerPage))))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Launchpad 風格的半透明背景
                LaunchpadBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 頂部間距
                    Spacer().frame(height: 20)
                    
                    // 搜尋欄
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 80)
                        .onChange(of: searchText) { _, _ in
                            currentPage = 0
                            dragAmount = .zero
                        }
                    
                    // 主要內容區域
                    ZStack {
                        // 分頁內容
                        ForEach(0..<totalPages, id: \.self) { pageIndex in
                            PageView(
                                apps: appsForPage(pageIndex),
                                columns: gridColumns,
                                pageIndex: pageIndex,
                                currentPage: currentPage,
                                screenWidth: geometry.size.width,
                                dragAmount: dragAmount
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle()) // 確保整個區域可以接收手勢
                    .background(
                        // 添加觸控板雙指滾動支援
                        TouchpadScrollView { deltaX in
                            print("收到滾動事件: \(deltaX)")
                            if abs(deltaX) > 2 {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    if deltaX > 0 && currentPage > 0 {
                                        print("切換到上一頁: \(currentPage - 1)")
                                        currentPage -= 1
                                    } else if deltaX < 0 && currentPage < totalPages - 1 {
                                        print("切換到下一頁: \(currentPage + 1)")
                                        currentPage += 1
                                    }
                                }
                            }
                        }
                    )
                    .gesture(
                        // 保留拖拽手勢作為備用
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                dragAmount = value.translation
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if value.translation.width > threshold && currentPage > 0 {
                                        currentPage -= 1
                                    } else if value.translation.width < -threshold && currentPage < totalPages - 1 {
                                        currentPage += 1
                                    }
                                    dragAmount = .zero
                                }
                            }
                    )
                    
                    // 頁面指示器
                    if totalPages > 1 && searchText.isEmpty {
                        PageIndicator(currentPage: currentPage, totalPages: totalPages) { page in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = page
                                dragAmount = .zero
                            }
                        }
                        .padding(.bottom, 60)
                    } else {
                        Spacer().frame(height: 60)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadInstalledApps()
            setupScrollMonitor()
        }
        .onDisappear {
            removeScrollMonitor()
        }
    }
    
    // 設置全域滾輪事件監聽
    private func setupScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let deltaX = event.scrollingDeltaX
            
            // 調試輸出（可以移除）
            print("滾輪事件 - phase: \(event.phase.rawValue), momentumPhase: \(event.momentumPhase.rawValue), deltaX: \(deltaX)")
            
            // 只處理手勢的真正開始，且不在滾動進行中
            if event.phase == .began && !scrollGestureInProgress {
                // 只處理明顯的水平滾動
                if abs(deltaX) > abs(event.scrollingDeltaY) && abs(deltaX) > 0.5 {
                    DispatchQueue.main.async {
                        print("觸發頁面切換 - deltaX: \(deltaX)")
                        
                        // 立即標記手勢開始
                        scrollGestureInProgress = true
                        
                        // 執行頁面切換
                        withAnimation(.easeOut(duration: 0.25)) {
                            if deltaX > 0 && currentPage > 0 {
                                currentPage -= 1
                                print("切換到上一頁: \(currentPage)")
                            } else if deltaX < 0 && currentPage < totalPages - 1 {
                                currentPage += 1
                                print("切換到下一頁: \(currentPage)")
                            }
                        }
                    }
                }
            }
            
            // 當慣性滾動完全結束時，重置狀態
            if event.momentumPhase == .ended {
                DispatchQueue.main.async {
                    scrollGestureInProgress = false
                    print("慣性滾動結束，重置狀態")
                }
            }
            
            return event
        }
    }
    
    // 移除事件監聽器
    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        gestureResetTimer?.invalidate()
        gestureResetTimer = nil
    }
    
    private func appsForPage(_ page: Int) -> [AppItem] {
        let startIndex = page * appsPerPage
        let endIndex = min(startIndex + appsPerPage, filteredApps.count)
        return Array(filteredApps[startIndex..<endIndex])
    }
}

// 單個頁面視圖
struct PageView: View {
    let apps: [AppItem]
    let columns: [GridItem]
    let pageIndex: Int
    let currentPage: Int
    let screenWidth: CGFloat
    let dragAmount: CGSize
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(apps, id: \.id) { app in
                AppIcon(app: app)
            }
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
        .offset(
            x: CGFloat(
                pageIndex - currentPage
            ) * screenWidth + dragAmount.width,
            y: 0
        )
        .opacity(pageIndex == currentPage ? 1.0 : 0.8)
        .scaleEffect(pageIndex == currentPage ? 1.0 : 0.95)
        .allowsHitTesting(pageIndex == currentPage) // 只有當前頁面可以接收點擊
    }
}

// 應用程式圖示
struct AppIcon: View {
    let app: AppItem
    @State private var isHovered = false
    @State private var isPressed = false
    @EnvironmentObject var viewModel: LaunchpadViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖示
            Group {
                if let icon = app.appIcon, icon.size.width > 0 {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // 預設圖示 - 使用更好看的設計
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "app.dashed")
                                .font(.title2)
                                .foregroundStyle(.primary.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.05 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            
            // 名稱
            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 70, maxHeight: 30)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            isPressed = true
            viewModel.launchApp(app)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

// 搜尋欄
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("搜尋", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// 頁面指示器
struct PageIndicator: View {
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: Capsule())
    }
}

// Launchpad 風格的半透明背景
struct LaunchpadBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 保持背景狀態
    }
}

// 觸控板雙指滾動視圖
struct TouchpadScrollView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> ScrollDetectorView {
        let view = ScrollDetectorView()
        view.scrollCallback = onScroll
        return view
    }
    
    func updateNSView(_ nsView: ScrollDetectorView, context: Context) {
        nsView.scrollCallback = onScroll
    }
}

// 檢測滾輪事件的自定義 NSView
class ScrollDetectorView: NSView {
    var scrollCallback: ((CGFloat) -> Void)?
    private var lastScrollTime: CFTimeInterval = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        // 使用現代的觸控事件 API
        self.allowedTouchTypes = [.direct, .indirect]
    }
    
    override func scrollWheel(with event: NSEvent) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // 防止事件過於頻繁
        guard currentTime - lastScrollTime > 0.05 else { return }
        lastScrollTime = currentTime
        
        let deltaX = event.scrollingDeltaX
        
        print("滾輪事件: deltaX = \(deltaX), deltaY = \(event.scrollingDeltaY)")
        
        // 降低閾值，讓滾動更敏感
        if abs(deltaX) > 1.0 {
            DispatchQueue.main.async {
                self.scrollCallback?(deltaX)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 確保視圖可以接收事件
        self.window?.makeFirstResponder(self)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.window?.makeFirstResponder(self)
    }
}

#Preview {
    ContentView()
}
