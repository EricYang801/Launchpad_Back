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
    @State private var scrollMonitor: Any?
    @State private var scrollGestureInProgress = false
    @State private var keyMonitor: Any?
    
    // 配置
    private let appsPerPage = 35
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    
    // 計算屬性
    private var filteredApps: [AppItem] {
        let uniqueApps = Dictionary(grouping: viewModel.apps, by: \.bundleID)
            .compactMapValues(\.first)
            .values
            .sorted { $0.name < $1.name }
        
        return searchText.isEmpty ? Array(uniqueApps) 
            : uniqueApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredApps.count) / Double(appsPerPage))))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LaunchpadBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 80)
                        .onChange(of: searchText) { _, _ in
                            currentPage = 0
                            dragAmount = .zero
                        }
                    
                    ZStack {
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
                    .contentShape(Rectangle())
                    .background(
                        TouchpadScrollView { deltaX in
                            handleScroll(deltaX: deltaX)
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { dragAmount = $0.translation }
                            .onEnded(handleDragEnd)
                    )
                    
                    if totalPages > 1 && searchText.isEmpty {
                        PageIndicator(currentPage: currentPage, totalPages: totalPages, onPageTap: switchToPage)
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
            setupKeyMonitor()
        }
        .onDisappear {
            removeScrollMonitor()
            removeKeyMonitor()
        }
    }
    
    // MARK: - Helper Methods
    private func handleScroll(deltaX: CGFloat) {
        guard abs(deltaX) > 0.5 else { return }
        
        withAnimation(.easeOut(duration: 0.25)) {
            if deltaX > 0 && currentPage > 0 {
                currentPage -= 1
            } else if deltaX < 0 && currentPage < totalPages - 1 {
                currentPage += 1
            }
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 30
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if value.translation.width > threshold && currentPage > 0 {
                currentPage -= 1
            } else if value.translation.width < -threshold && currentPage < totalPages - 1 {
                currentPage += 1
            }
            dragAmount = .zero
        }
    }
    
    private func switchToPage(_ page: Int) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentPage = page
            dragAmount = .zero
        }
    }
    
    private func setupScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let deltaX = event.scrollingDeltaX
            
            if event.phase == .began && !scrollGestureInProgress {
                if abs(deltaX) > abs(event.scrollingDeltaY) && abs(deltaX) > 0.2 {
                    DispatchQueue.main.async {
                        scrollGestureInProgress = true
                        handleScroll(deltaX: deltaX)
                    }
                }
            }
            
            if event.momentumPhase == .ended {
                DispatchQueue.main.async {
                    scrollGestureInProgress = false
                }
            }
            
            return event
        }
    }
    
    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Command + W to hide window
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                NSApplication.shared.keyWindow?.orderOut(nil)
                return nil
            }
            
            // Command + Q to terminate app
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
                return nil
            }
            
            // Escape key to deselect search bar or hide window
            if event.keyCode == 53 { // 53 is the keycode for Escape key
                if !searchText.isEmpty {
                    searchText = ""
                } else {
                    NSApplication.shared.keyWindow?.orderOut(nil)
                }
                return nil
            }
            
            // Left arrow key to go to the previous page
            if event.keyCode == 123 { // 123 is the keycode for Left Arrow
                if self.currentPage > 0 {
                    self.currentPage -= 1
                }
                return nil
            }
            
            // Right arrow key to go to the next page
            if event.keyCode == 124 { // 124 is the keycode for Right Arrow
                if self.currentPage < self.totalPages - 1 {
                    self.currentPage += 1
                }
                return nil
            }
            
            return event
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
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
                    defaultIcon
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
        .onHover { isHovered = $0 }
        .onTapGesture {
            isPressed = true
            viewModel.launchApp(app)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
    
    private var defaultIcon: some View {
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

// 搜尋欄
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search", text: $text)
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
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        allowedTouchTypes = [.direct, .indirect]
    }
    
    override func scrollWheel(with event: NSEvent) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - lastScrollTime > 0.05 else { return }
        lastScrollTime = currentTime
        
        let deltaX = event.scrollingDeltaX
        if abs(deltaX) > 1.0 {
            DispatchQueue.main.async {
                self.scrollCallback?(deltaX)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        window?.makeFirstResponder(self)
    }
}

#Preview {
    ContentView()
}
