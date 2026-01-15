//
//  ContentView.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var launchpadVM = LaunchpadViewModel()
    @StateObject private var searchVM = SearchViewModel()
    @StateObject private var paginationVM = PaginationViewModel()
    
    var body: some View {
        LaunchpadView()
            .environmentObject(launchpadVM)
            .environmentObject(searchVM)
            .environmentObject(paginationVM)
    }
}

struct LaunchpadView: View {
    @EnvironmentObject var launchpadVM: LaunchpadViewModel
    @EnvironmentObject var searchVM: SearchViewModel
    @EnvironmentObject var paginationVM: PaginationViewModel
    
    @State private var dragAmount = CGSize.zero
    @State private var keyboardManager: KeyboardEventManager?
    @State private var gestureManager: GestureManager?
    
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    
    private var filteredApps: [AppItem] {
        let uniqueApps = Dictionary(grouping: launchpadVM.apps, by: \.bundleID)
            .compactMapValues(\.first)
            .values
            .sorted { $0.name < $1.name }
        
        return searchVM.filterApps(Array(uniqueApps), by: searchVM.searchText)
    }
    
    private var totalPages: Int {
        paginationVM.totalPages(for: filteredApps.count)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BackgroundView()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    SearchBarView(text: $searchVM.searchText)
                        .padding(.horizontal, 80)
                        .onChange(of: searchVM.searchText) { _, _ in
                            paginationVM.reset()
                            dragAmount = .zero
                        }
                    
                    ZStack {
                        ForEach(0..<totalPages, id: \.self) { pageIndex in
                            PageView(
                                apps: paginationVM.appsForPage(filteredApps, page: pageIndex),
                                columns: gridColumns,
                                pageIndex: pageIndex,
                                currentPage: paginationVM.currentPage,
                                screenWidth: geometry.size.width,
                                dragAmount: dragAmount,
                                onAppTap: launchpadVM.launchApp
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { dragAmount = $0.translation }
                            .onEnded(handleDragEnd)
                    )
                    
                    if totalPages > 1 && searchVM.searchText.isEmpty {
                        PageIndicatorView(
                            currentPage: paginationVM.currentPage,
                            totalPages: totalPages,
                            onPageTap: { page in
                                paginationVM.jumpToPage(page, totalPages: totalPages)
                                dragAmount = .zero
                            }
                        )
                        .padding(.bottom, 60)
                    } else {
                        Spacer().frame(height: 60)
                    }
                }
            }
        }
        .onAppear {
            launchpadVM.loadInstalledApps()
            setupEventManagers()
        }
        .onDisappear {
            teardownEventManagers()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupEventManagers() {
        keyboardManager = KeyboardEventManager(
            onLeftArrow: { paginationVM.previousPage() },
            onRightArrow: { paginationVM.nextPage(totalPages: totalPages) },
            onEscape: handleEscapeKey,
            onCommandW: hideWindow,
            onCommandQ: quitApp
        )
        keyboardManager?.startListening()
        
        // 新的 GestureManager API：傳遞頁面切換方向（-1=上一頁, +1=下一頁）
        gestureManager = GestureManager { [weak paginationVM, weak launchpadVM, weak searchVM] direction in
            guard let paginationVM = paginationVM,
                  let launchpadVM = launchpadVM,
                  let searchVM = searchVM else { return }
            
            // 計算過濾後的 app 數量
            let uniqueApps = Dictionary(grouping: launchpadVM.apps, by: \.bundleID)
                .compactMapValues(\.first)
                .values
            let filteredCount = searchVM.filterApps(Array(uniqueApps), by: searchVM.searchText).count
            let totalPages = paginationVM.totalPages(for: filteredCount)
            
            Logger.debug("Page change requested: direction=\(direction), currentPage=\(paginationVM.currentPage), totalPages=\(totalPages)")
            
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.20)) {
                    if direction > 0 {
                        paginationVM.nextPage(totalPages: totalPages)
                    } else {
                        paginationVM.previousPage()
                    }
                }
            }
        }
        gestureManager?.startListening()
    }
    
    private func teardownEventManagers() {
        keyboardManager?.stopListening()
        gestureManager?.stopListening()
        keyboardManager = nil
        gestureManager = nil
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 30
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            if value.translation.width > threshold {
                paginationVM.previousPage()
            } else if value.translation.width < -threshold {
                paginationVM.nextPage(totalPages: totalPages)
            }
            dragAmount = .zero
        }
    }
    
    private func handleEscapeKey() {
        if !searchVM.searchText.isEmpty {
            searchVM.clearSearch()
        } else {
            hideWindow()
        }
    }
    
    private func hideWindow() {
        NSApplication.shared.keyWindow?.orderOut(nil)
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}

#Preview {
    ContentView()
}
