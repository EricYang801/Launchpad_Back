# Launchpad_Back 改寫後 - 快速開始指南

## 🚀 編譯和運行

### 1. 構建項目
```bash
# 使用 Xcode 構建
ㄎ
# 或在 Xcode 中
Command + B
```

### 2. 運行應用
```bash
# 使用 Xcode 運行
Command + R

# 或直接運行應用
open /Users/ericyang/Github/Launchpad_Back/Launchpad_Back.app
```

### 3. 全局快捷鍵
- **Command + L** - 顯示/隱藏 Launchpad
- **Command + W** - 隱藏窗口
- **Command + Q** - 退出應用
- **Escape** - 清除搜尋或隱藏窗口
- **左/右箭頭** - 上一頁/下一頁

---

## 🧪 驗證改寫

### 檢查列表

#### 1. 編譯驗證
- [ ] 項目無編譯錯誤
- [ ] 項目無警告
- [ ] 所有導入正確

```bash
# 檢查編譯警告
xcodebuild build -scheme Launchpad_Back 2>&1 | grep warning
```

#### 2. 功能驗證

**應用掃描**
```
✅ 啟動應用
✅ 應用列表顯示完整
✅ 系統應用和用戶應用都顯示
✅ 應用圖示正確加載
✅ 應用名稱正確顯示
```

**搜尋功能**
```
✅ 在搜尋框輸入文本
✅ 應用列表自動篩選
✅ 搜尋結果準確
✅ 清除搜尋按鈕工作
✅ Escape 鍵清除搜尋
```

**分頁導航**
```
✅ 多頁應用正確分頁
✅ 頁面指示器顯示正確
✅ 點擊頁面點滑動到該頁
✅ 左/右箭頭鍵導航頁面
✅ 觸控板雙指滾動工作
✅ 鼠標拖動手勢工作
```

**應用啟動**
```
✅ 單擊應用啟動
✅ 應用正確打開
✅ 啟動動畫流暢
✅ 所有應用都可啟動
```

**快捷鍵**
```
✅ Command + L 全局快捷鍵工作
✅ Command + W 隱藏窗口
✅ Command + Q 退出應用
✅ 所有其他快捷鍵工作
```

#### 3. 性能驗證

**啟動時間**
```
測量應用啟動到完全加載的時間
預期：< 2 秒
```

**內存使用**
```
Activity Monitor 檢查內存使用
預期：< 200 MB（取決於應用數量）
```

**CPU 使用**
```
在應用列表時 CPU 使用接近 0%
拖動頁面時不超過 50%
```

#### 4. 日誌驗證

打開 Xcode 控制台查看日誌：

```
[HH:MM:SS.SSS] 🔵 DEBUG [LaunchpadViewModel:24] LaunchpadViewModel initialized
[HH:MM:SS.SSS] 🟢 INFO [Launchpad_BackApp:36] Application did finish launching
[HH:MM:SS.SSS] 🟢 INFO [LaunchpadViewModel:56] Starting app loading...
[HH:MM:SS.SSS] 🟢 INFO [LaunchpadViewModel:66] App loading completed. Found 142 applications
[HH:MM:SS.SSS] 🟢 INFO [AppDelegate:79] Global hot key registered successfully
```

---

## 📚 代碼導覽

### Models 層

#### AppItem.swift
```swift
// 應用程式數據模型
struct AppItem {
    let id: UUID              // 唯一標識
    let name: String          // 應用名稱
    let bundleID: String      // Bundle ID
    let path: String          // 應用路徑
    let isSystemApp: Bool     // 是否系統應用
    var appIcon: NSImage?     // 應用圖示
}
```

### Services 層

#### AppScannerService.swift
```swift
// 掃描應用程式
let scanner = AppScannerService()
let apps = scanner.scanInstalledApps()
// 並行掃描多個目錄，自動去重和排序
```

#### AppLauncherService.swift
```swift
// 啟動應用程式
let launcher = AppLauncherService()
let success = launcher.launch(app)  // 同步
launcher.launchAsync(app) { success in }  // 異步
```

#### AppIconCache.swift
```swift
// 智能圖示快取
let icon = AppIconCache.shared.getIcon(for: path)
AppIconCache.shared.getIconAsync(for: path) { icon in }
AppIconCache.shared.clearCache()

// 查看快取統計
let stats = AppIconCache.shared.getCacheStatistics()
print("快取應用圖示：\(stats.count)個，大小：\(stats.size)")
```

#### Logger.swift
```swift
// 日誌記錄
Logger.debug("調試信息")
Logger.info("信息")
Logger.warning("警告")
Logger.error("錯誤")
Logger.error(error)
```

#### KeyboardEventManager.swift
```swift
// 鍵盤事件管理
let manager = KeyboardEventManager(
    onLeftArrow: { print("上一頁") },
    onRightArrow: { print("下一頁") },
    onEscape: { print("ESC") },
    onCommandW: { print("Cmd+W") },
    onCommandQ: { print("Cmd+Q") }
)
manager.startListening()
// ...
manager.stopListening()
```

#### GestureManager.swift
```swift
// 手勢事件管理
let manager = GestureManager { deltaX in
    print("滾輪事件：\(deltaX)")
}
manager.startListening()
// ...
manager.stopListening()
```

### ViewModels 層

#### LaunchpadViewModel.swift
```swift
@ObservedObject var viewModel = LaunchpadViewModel()

// 屬性
viewModel.apps               // 應用列表
viewModel.isLoading          // 加載狀態
viewModel.errorMessage       // 錯誤訊息

// 方法
viewModel.loadInstalledApps()  // 加載應用
viewModel.launchApp(app)       // 啟動應用
viewModel.refreshApps()        // 刷新列表
viewModel.clearError()         // 清除錯誤
```

#### SearchViewModel.swift
```swift
@ObservedObject var searchVM = SearchViewModel()

// 屬性
searchVM.searchText            // 搜尋文本
searchVM.currentPage           // 當前頁面

// 方法
searchVM.filterApps(apps, by: text)  // 篩選應用
searchVM.clearSearch()               // 清除搜尋
searchVM.resetPage()                 // 重置頁面
```

#### PaginationViewModel.swift
```swift
@ObservedObject var paginationVM = PaginationViewModel(appsPerPage: 35)

// 方法
paginationVM.totalPages(for: count)           // 計算總頁數
paginationVM.appsForPage(apps, page: 0)      // 獲取頁面應用
paginationVM.previousPage()                   // 上一頁
paginationVM.nextPage(totalPages: 10)         // 下一頁
paginationVM.jumpToPage(5, totalPages: 10)    // 跳轉頁面
paginationVM.reset()                          // 重置到第一頁
```

### Views 層

#### SearchBarView.swift
```swift
@State var searchText = ""
SearchBarView(text: $searchText)
// 提供搜尋框 UI
```

#### AppIconView.swift
```swift
let app = AppItem(...)
AppIconView(app: app) {
    // 點擊應用時執行
}
// 顯示應用圖示和名稱
```

#### PageView.swift
```swift
PageView(
    apps: appList,
    columns: gridColumns,
    pageIndex: 0,
    currentPage: 0,
    screenWidth: 1200,
    dragAmount: .zero,
    onAppTap: { app in }
)
// 顯示一頁的應用
```

#### PageIndicatorView.swift
```swift
PageIndicatorView(currentPage: 0, totalPages: 5) { page in }
// 顯示頁面指示點
```

---

## 🐛 常見問題排查

### 問題 1：應用不加載
```
症狀：啟動後應用列表為空
排查：
1. 檢查日誌中是否有錯誤
2. 確認 /Applications 目錄存在
3. 確認應用有讀取權限
```

### 問題 2：圖示無法加載
```
症狀：應用顯示默認圖示
排查：
1. 檢查 AppIconCache 是否工作
2. 確認應用有有效的 .icns 文件
3. 檢查文件權限
```

### 問題 3：搜尋不工作
```
症狀：搜尋框無響應
排查：
1. 檢查 SearchViewModel 的過濾邏輯
2. 確認 searchText 綁定正確
3. 驗證應用 bundleID 是否正確解析
```

### 問題 4：快捷鍵無效
```
症狀：Command + L 等快捷鍵不工作
排查：
1. 檢查 AppDelegate 是否初始化
2. 查看日誌中快捷鍵是否註冊
3. 確認應用已獲得輔助功能權限
```

### 問題 5：崩潰和異常
```
症狀：應用閃退
排查：
1. 檢查 Xcode 控制台的錯誤訊息
2. 查看 crash 日誌
3. 啟用異常斷點：Xcode → Breakpoints → Create Exception Breakpoint
```

---

## 🔍 調試技巧

### 1. 啟用詳細日誌

編輯 Logger.swift，修改 DEBUG 條件：
```swift
#if DEBUG
    // 日誌將在 DEBUG 模式打印
#endif
```

### 2. 性能分析

使用 Xcode Instruments：
```
Xcode → Product → Profile → Time Profiler
// 分析應用性能瓶頸
```

### 3. 內存檢測

使用 Xcode Instruments：
```
Xcode → Product → Profile → Allocations
// 檢查內存泄漏
```

### 4. 視圖層次檢查

```swift
// 在 ContentView 中添加調試視圖
#if DEBUG
VStack {
    // 調試信息
    Text("應用數：\(launchpadVM.apps.count)")
    Text("當前頁：\(paginationVM.currentPage)")
}
#endif
```

### 5. 事件日誌

在 KeyboardEventManager 中添加：
```swift
private func handleKeyEvent(_ event: NSEvent) {
    Logger.debug("Key event: code=\(event.keyCode)")
    // ...
}
```

---

## 📈 性能優化建議

### 1. 圖示加載優化
```swift
// 使用異步加載減少 UI 卡頓
AppIconCache.shared.getIconAsync(for: path) { icon in
    DispatchQueue.main.async {
        // 更新 UI
    }
}
```

### 2. 列表虛擬化
```swift
// 使用 LazyVGrid 而非 VGrid
LazyVGrid(columns: columns) {
    // 只渲染可見項目
}
```

### 3. 動畫優化
```swift
// 使用簡單動畫
withAnimation(.easeOut(duration: 0.25)) {
    // 避免複雜的 @State 更新
}
```

---

## ✅ 下一步

1. **添加單元測試**
   - 測試 AppScannerService
   - 測試搜尋邏輯
   - 測試分頁計算

2. **擴展功能**
   - 添加應用分類
   - 實現最近使用
   - 支持應用分組

3. **性能監控**
   - 測量加載時間
   - 監控內存使用
   - 分析快取效率

4. **用戶體驗改進**
   - 添加載入動畫
   - 優化搜尋體驗
   - 改進導航反饋

---

## 📞 獲得幫助

如果遇到問題，檢查以下資源：
1. Xcode 文檔 - Help → Documentation
2. Apple 開發者論壇 - developer.apple.com
3. Stack Overflow - swiftui 標籤
4. GitHub Issues - 項目問題追蹤

---

**祝你使用愉快！** 🎉
