# Launchpad_Back — 在 macOS Tahoe (26) 找回經典 Launchpad

> 讓 Launchpad 回到 macOS 26 Tahoe：全螢幕應用程式網格、分頁、資料夾、拖曳排列，免費且開放原始碼。

**[English](./README.md) | [繁體中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

<div align="center">
  <a href="https://github.com/EricYang801/Launchpad_Back/releases/latest">
    <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="下載次數" />
  </a>
  <br /><br />
  <strong><a href="https://github.com/EricYang801/Launchpad_Back/releases/latest">⬇ 下載最新版本</a></strong>
  <br /><br />
  <img src="./Example.png" alt="Launchpad_Back 在 macOS Tahoe 上的畫面：模糊桌面背景上的全螢幕 Launchpad 應用程式網格、資料夾與分頁圓點" />
</div>

## 為什麼做這個

Apple 在 macOS 26 Tahoe 移除了 Launchpad，改用 Spotlight 裡的「App」檢視取代。如果你懷念那個熟悉的全螢幕圖示網格——左右滑動切換頁面、把 App 收進資料夾、照自己的習慣排列——Launchpad_Back 就是把它找回來的。這是用 SwiftUI + AppKit 寫的原生 App，以 GPL-3.0 授權免費開源。

## 功能

- **跟原版一樣全螢幕**：在滑鼠指標所在的螢幕上鋪滿整個畫面，背景是模糊、調暗的桌面背景圖片（取不到時改用系統模糊材質），開啟與關閉都有縮放淡入淡出動畫。
- **分頁圖示網格**：預設 7 欄 × 5 列，和原版 Launchpad 相同；可在設定中調整欄數（4–12）與列數（3–9）。底部的分頁圓點可直接點選。
- **順手的翻頁方式**：觸控式軌跡板雙指滑動會跟著手指移動並自動對齊；滑鼠滾輪每滾一格翻一頁；在空白處按住拖曳也能翻頁；方向鍵同樣可用。
- **Big Sur 風格資料夾**：半透明方塊預覽 9 個 App。把一個 App 拖到另一個 App 上就會建立資料夾，並依 App Store 類別自動命名（例如「開發者工具」、「遊戲」），同時打開讓你直接改名。點資料夾標題即可重新命名，把 App 拖出資料夾即可移除。資料夾只剩一個 App 時會自動變回該 App。超過 15 個 App 的資料夾會分頁顯示。
- **編輯模式**：長按圖示或直接開始拖曳即可進入。圖示會抖動，拖曳時其他圖示即時讓位；把圖示停在螢幕邊緣就能移到其他頁。點空白處或按 `Esc` 結束。
- **打字就能搜尋**：直接開始輸入即可。會比對在地化的 App 名稱、英文名稱、bundle ID 與路徑，名稱開頭相符的排在最前面。用方向鍵移動選取，按 `Return` 開啟。
- **全域快捷鍵**：預設 `⌘L`，可在設定中重新錄製。`F1`–`F20` 可單獨使用，設成 `F4` 就跟以前的 Launchpad 鍵一樣。
- **找得到你所有的應用程式**：`/System/Applications`（含「工具程式」）、`/Applications` 及其子資料夾（例如 Adobe 套裝）、`~/Applications`，以及 Apple 晶片（`/opt/homebrew`）與 Intel（`/usr/local`）上的 Homebrew Caskroom。每次開啟 Launchpad 都會重新掃描，新安裝或刪除的 App 會立刻反映。
- **保留你的排列**：順序與資料夾都儲存在本機。暫時找不到的 App（例如放在未接上的外接硬碟）會保留原本的位置，回來時歸位。2.x 版的排列會自動移轉。
- **記憶體佔用極低**：安裝約 150 個 App 時只用大約 40 MB 記憶體。圖示依實際顯示大小產生，搜尋結果每個關鍵字只計算一次，重新掃描沒有變化時也不會重繪畫面。
- **多語系介面**：英文、繁體中文、簡體中文。

## 安裝

1. 從 **[最新版本](https://github.com/EricYang801/Launchpad_Back/releases/latest)** 下載 `Launchpad_Back.app.zip`。
2. 解壓縮。
3. 把 `Launchpad_Back.app` 移到「應用程式」資料夾（`/Applications`）。
4. 開啟 App，然後按 `⌘L`（或點 Dock 圖示）叫出 Launchpad。

### 系統需求

- macOS 15.6 或更新版本（可在 macOS 26 Tahoe 上使用）
- Apple 晶片或 Intel 處理器的 Mac

### 第一次開啟

本 App 採用 ad-hoc 簽署，未經 Apple 公證（notarization），所以第一次開啟時會被 macOS 擋下。請擇一處理：

- 在 `Launchpad_Back.app` 上按右鍵（或 Control 鍵加按一下）→「**打開**」，再確認一次；或
- 先試著開啟一次，再到「**系統設定 → 隱私權與安全性**」按「**強制打開**」。

只需要做一次。

## 使用方式

| 動作 | 操作 |
| --- | --- |
| 顯示／隱藏 Launchpad | 全域快捷鍵（預設 `⌘L`）、點 Dock 圖示，或再次開啟 App |
| 開啟應用程式 | 點一下圖示 |
| 翻頁 | 雙指滑動、滑鼠滾輪、在空白處按住拖曳、`←` / `→`，或點分頁圓點 |
| 搜尋 | 直接打字；`↑` `↓` `←` `→` 移動選取，`Return` 開啟 |
| 進入編輯模式 | 長按圖示，或直接拖曳圖示 |
| 把 App 移到其他頁 | 拖曳圖示並停在螢幕左右邊緣 |
| 建立資料夾 | 把 App 拖到另一個 App 上 |
| 重新命名資料夾 | 點資料夾標題 |
| 把 App 移出資料夾 | 從打開的資料夾中拖出來 |
| 退回上一步 | `Esc`：取消拖曳 → 關閉資料夾 → 離開編輯模式 → 清除搜尋 → 關閉 Launchpad |
| 關閉 Launchpad | 開啟 App、點空白處、切換到其他 App，或按 `⌘W` |
| 打開設定 | `⌘,` |
| 結束 App | `⌘Q` |

## 設定

在 Launchpad 開啟時按 `⌘,`。

<img src="./Settings.png" alt="Launchpad_Back 設定視窗：全域快捷鍵、登入時開啟、在 Dock 中顯示、網格欄數與列數、重設版面" width="450" />

- **快捷鍵**：點按鈕後按下新的組合鍵。一般按鍵需搭配 `⌘`、`⌥` 或 `⌃`；`F1`–`F20` 可單獨使用。
- **登入時開啟**：登入 Mac 時自動啟動 Launchpad_Back。
- **在 Dock 中顯示**：關閉即可隱藏 Dock 圖示。
- **網格**：欄數（4–12）與列數（3–9）。
- **重設版面**：清除自訂順序與資料夾。

## 常見問題

### macOS Tahoe 的 Launchpad 跑去哪了？

Apple 在 macOS 26 Tahoe 移除了 Launchpad，改由 Spotlight 裡的「App」檢視取代。它會列出應用程式，但沒有可以自由排列的分頁和資料夾。

### 怎麼在 macOS 26 把 Launchpad 找回來？

從 [最新版本](https://github.com/EricYang801/Launchpad_Back/releases/latest) 安裝 Launchpad_Back，第一次開啟時允許執行（見[第一次開啟](#第一次開啟)），然後按 `⌘L`。在設定中打開「登入時開啟」，它就會一直待命。

### 可以像以前一樣用 F4 叫出 Launchpad 嗎？

可以。按 `⌘,` 打開設定，點快捷鍵按鈕後按 `F4` 即可。`F1`–`F20` 不需搭配修飾鍵。很多 Mac 鍵盤需要同時按住 `fn`，或在「系統設定 → 鍵盤」中啟用「將 F1、F2 等鍵作為標準功能鍵使用」。

### 我的資料夾會保留嗎？

會。順序和資料夾都儲存在本機，重新開機或更新後依然存在。Launchpad_Back 2.x 版的排列會自動移轉。不過它不會匯入 Apple 舊版 Launchpad 的排列。

### 需要給什麼權限嗎？

不需要。全域快捷鍵使用 Carbon hot key 機制，不必開啟「輔助使用」權限。

### 這是 Apple 的 App 嗎？

不是。Launchpad_Back 是獨立的開源專案，與 Apple 沒有任何關係，也未獲 Apple 背書。「Launchpad」與「macOS」是 Apple Inc. 的商標。

## 從原始碼建置

需要 Xcode 26。

```bash
git clone https://github.com/EricYang801/Launchpad_Back.git
cd Launchpad_Back
open Launchpad_Back.xcodeproj   # 接著按 ⌘R
```

或使用「終端機」：

```bash
xcodebuild build -scheme Launchpad_Back -destination 'platform=macOS'
```

執行單元測試：

```bash
xcodebuild test -scheme Launchpad_Back -destination 'platform=macOS' -only-testing:Launchpad_BackTests
```

## 參與貢獻

歡迎回報問題、提出建議或送 Pull Request；較大的修改請先[開一個 issue](https://github.com/EricYang801/Launchpad_Back/issues) 討論。

```text
Launchpad_Back/
├── App/        App delegate、視窗控制器、輸入處理、全域快捷鍵
├── Model/      資料儲存、排列、網格尺寸、偏好設定
├── Services/   應用程式掃描、圖示快取、桌面背景
├── Views/      SwiftUI 視圖
└── Localizable.xcstrings   英文、繁體中文、簡體中文字串
```

## 授權

[GPL-3.0](./LICENSE) © [EricYang801](https://github.com/EricYang801)

Launchpad_Back 與 Apple Inc. 無任何關聯。
