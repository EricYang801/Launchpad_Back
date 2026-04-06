# Launchpad_Back

> 一個用 SwiftUI 製作、在現代 macOS 上取代 Launchpad 的啟動器。

<div align="center">
  <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="下載次數" />
</div>

**[English](./README.md) | [繁體中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

## 畫面演示
![主介面](./Example.png)

## 概述

Launchpad_Back 是一個為 macOS 15.6 以上版本打造的 Launchpad 替代方案。它會掃描常見應用程式目錄，將 App 顯示成可分頁的網格，支援資料夾、拖曳排序、全域快捷鍵，以及類似原生 Launchpad 的浮動視窗體驗。

Apple 在 macOS 26 Tahoe 移除了 Launchpad，這個專案就是為了把那套工作流帶回來，同時保留 SwiftUI + AppKit 的原生整合。

## 主要功能

- **應用程式掃描**
  - 掃描 `/Applications`
  - 掃描 `/System/Applications`
  - 掃描 `/System/Applications/Utilities`
  - 掃描使用者 Applications 目錄
  - 遞迴掃描 `/opt/homebrew/Caskroom` 內的 Homebrew Cask 安裝

- **Launchpad 式瀏覽**
  - 自動分頁的網格排列
  - 滑鼠拖曳與方向鍵翻頁
  - 由事件管理層處理的觸控板手勢
  - 即時搜尋與篩選

- **整理與編輯**
  - 拖曳重新排序
  - 把 App 拖到另一個 App 上可建立資料夾
  - 把 App 拖到資料夾上可加入資料夾
  - 在展開資料夾中重新排序內容
  - 從展開資料夾拖出 App 可移出資料夾
  - 提供重設版面按鈕，可清除資料夾並恢復依名稱排序

- **視窗與快捷鍵**
  - 全域 `Cmd + L` 切換顯示
  - `Cmd + W` 隱藏視窗
  - `Cmd + Q` 結束程式
  - `Esc` 依情境清除搜尋、關閉資料夾、退出編輯或隱藏視窗

- **圖示處理流程**
  - 先解析 symlink 後再載入 App bundle 圖示
  - 若 `NSWorkspace` 只給 generic app icon，會再讀 bundle metadata
  - 若 bundle 本身沒有可用圖示，會自動產生 initials fallback icon
  - 使用非同步快取讓分頁、拖曳與資料夾預覽保持順暢

## 專案結構

```text
Launchpad_Back/
├── Launchpad_BackApp.swift
├── ContentView.swift
├── Models/
│   └── AppItem.swift
├── Services/
│   ├── AppIconCache.swift
│   ├── AppIconResolver.swift
│   ├── AppLauncherService.swift
│   ├── AppScannerService.swift
│   ├── GestureManager.swift
│   ├── GridLayoutManager.swift
│   ├── KeyboardEventManager.swift
│   └── Logger.swift
├── ViewModels/
│   ├── EditModeManager.swift
│   ├── LaunchpadViewModel.swift
│   ├── PaginationViewModel.swift
│   └── SearchViewModel.swift
├── Views/
│   ├── AppIconView.swift
│   ├── BackgroundView.swift
│   ├── FolderExpandedView.swift
│   ├── PageIndicatorView.swift
│   └── SearchBarView.swift
└── Assets.xcassets/
```

## 核心元件

- **`LaunchpadViewModel`**
  - 管理掃描到的 App、資料夾與顯示順序
  - 用 `UserDefaults` 持久化排序與資料夾
  - 預載入相鄰頁面的 icon

- **`AppScannerService`**
  - 從系統、使用者與 Homebrew 位置掃描 `.app`
  - 從 `Info.plist` 讀取顯示名稱與 bundle identifier
  - 用穩定識別鍵去重

- **`AppIconResolver`**
  - 解析 canonical bundle path
  - 偵測 generic `NSWorkspace` icon
  - 讀取 `CFBundleIconFile`、`CFBundleIconName` 等 icon metadata
  - 在沒有可用圖示時生成 fallback icon

- **`AppIconCache`**
  - 以解析後的 bundle path 做快取鍵
  - 非同步載入主畫面、資料夾預覽與拖曳浮層圖示

## 系統需求

- macOS 15.6 或以上
- Xcode 17 或以上

## 編譯

1. 複製專案：

   ```bash
   git clone https://github.com/EricYang801/Launchpad_Back.git
   cd Launchpad_Back
   ```

2. 用 Xcode 開啟：

   ```bash
   open Launchpad_Back.xcodeproj
   ```

3. 執行：
  - 選擇 `My Mac`
  - 按 `Cmd + R`

也可以直接在 Terminal 編譯：

```bash
xcodebuild build -scheme Launchpad_Back -destination 'platform=macOS'
```

## 測試

執行單元測試：

```bash
xcodebuild test -scheme Launchpad_Back -destination 'platform=macOS' -only-testing:Launchpad_BackTests
```

目前測試涵蓋：
- 直接 bundle path 的 icon 解析
- symlink bundle 的 icon 解析
- metadata icon fallback
- 自動生成 fallback icon
- canonical bundle path 的 cache reuse
- 資料夾建立與還原
- 重設版面
- 搜尋與分頁

## 使用方式

### 基本流程

1. 按 `Cmd + L` 顯示或隱藏啟動器。
2. 點一下 App 圖示即可啟動。
3. 在搜尋列輸入文字即可過濾 App。
4. 使用方向鍵或拖曳手勢切換頁面。

### 編輯與資料夾

1. 長按任一項目進入編輯模式。
2. 把 App 拖到另一個 App 上建立資料夾。
3. 把 App 拖到現有資料夾上加入資料夾。
4. 打開資料夾後可以重新命名或調整內容順序。
5. 從展開資料夾把 App 拖出即可移出資料夾。
6. 使用重設版面按鈕可清除資料夾並恢復依名稱排序。

## 補充說明

- App identity 以 `bundleID` 為主，沒有 `bundleID` 的 App 會退回使用安裝路徑。
- 排序與資料夾配置會儲存在：
  - `launchpad_item_order`
  - `launchpad_folders`
- 若某些 App 最終仍只暴露 generic icon，Launchpad_Back 會顯示一致的 fallback icon，而不是虛線 placeholder。

## 授權

本專案採用 GPL-3.0。詳見 [LICENSE](./LICENSE)。
