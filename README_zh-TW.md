# Launchpad_Back (中文)

## 描述

這是一個使用 SwiftUI 開發的 macOS 應用程式，因為MacOS 26 Tahoe的啟動台被移除，為了使用方便，就寫了這個App，模擬原本啟動台的功能，包含搜尋、瀏覽和啟動已安裝的應用程式，提供熟悉的網格佈局和分頁介面。

![範例](./Example.jpg)

## 主要功能

*   **應用程式探索**：自動掃描並顯示來自標準 macOS 目錄 (`/Applications`, `/System/Applications`, `/System/Applications/Utilities`) 的所有應用程式。
*   **網格佈局與分頁**：將應用程式整齊地排列在網格中。如果應用程式數量超過單一螢幕的容量，會自動整理成多個頁面。
*   **流暢的導覽**：使用者可以透過多種方式在頁面之間切換：
    *   在觸控板上使用雙指滑動手勢。
    *   使用滑鼠點擊並拖曳。
    *   使用左、右方向鍵。
*   **即時搜尋**：頂部的搜尋欄讓使用者可以依名稱即時篩選應用程式。
*   **視覺風格**：採用了模仿原生 macOS Launchpad 的模糊半透明背景效果（有想辦法做得像Liquid Glass的效果但太難了）
*   **鍵盤快捷鍵**：
    *   `Cmd + W`：關閉 Launchpad 視窗。
    *   `Cmd + Q`：結束應用程式。
    *   `Esc`：清除搜尋內容，或在搜尋框為空時關閉視窗。
    *   `方向鍵`：切換頁面。
*   **效能優化**：
    *   應用程式掃描在背景執行緒中進行，以保持 UI 的流暢回應。
    *   應用程式圖示被非同步載入並進行快取。

## 運作原理

*   **`LaunchpadViewModel`**：這是應用程式的邏輯核心。它負責尋找所有的 `.app` 套件，解析其 `Info.plist` 以獲取元數據（如名稱和 Bundle ID），處理重複的項目，並將最終的應用程式列表提供給視圖。
*   **`ContentView`**：此檔案包含了構成使用者介面的所有 SwiftUI 視圖。
    *   `LaunchpadView`：組合所有其他元件的主視圖。
    *   `PageView`：代表網格中的單一頁面。
    *   `AppIcon`：用於顯示單個應用程式圖示及其名稱的視圖。
    *   `SearchBar`：搜尋元件。
    *   `PageIndicator`：底部用於指示目前頁面的圓點。
*   **手勢與事件處理**：應用程式結合了 `DragGesture`（用於滑鼠拖曳）、一個自訂的 `NSViewRepresentable` (`TouchpadScrollView`，用於偵測觸控板滾動），以及 `NSEvent.addLocalMonitorForEvents`（用於監聽全域鍵盤事件）。
