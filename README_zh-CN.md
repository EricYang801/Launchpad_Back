# Launchpad_Back

> 一个用 SwiftUI 编写、在现代 macOS 上替代 Launchpad 的启动器。

<div align="center">
  <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="下载次数" />
</div>

**[English](./README.md) | [繁体中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

## 界面演示
![主界面](./Example.png)

## 概述

Launchpad_Back 是为 macOS 15.6 及以上版本准备的 Launchpad 替代方案。它会扫描常见应用目录，把 App 以分页网格的形式显示出来，支持文件夹、拖拽排序、全局快捷键，以及类似原生 Launchpad 的浮动窗口体验。

Apple 在 macOS 26 Tahoe 中移除了 Launchpad，这个项目就是为了把那套使用方式带回来，同时保留 SwiftUI 与 AppKit 的原生集成。

## 主要功能

- **应用扫描**
  - 扫描 `/Applications`
  - 扫描 `/System/Applications`
  - 扫描 `/System/Applications/Utilities`
  - 扫描用户 Applications 目录
  - 递归扫描 `/opt/homebrew/Caskroom` 里的 Homebrew Cask 安装

- **Launchpad 风格浏览**
  - 自动分页的网格布局
  - 鼠标拖拽与方向键翻页
  - 通过事件管理层处理触控板手势
  - 实时搜索与过滤

- **整理与编辑**
  - 拖拽重新排序
  - 将 App 拖到另一个 App 上创建文件夹
  - 将 App 拖到文件夹上加入文件夹
  - 在展开的文件夹中重新排序内容
  - 从展开文件夹中拖出 App 以移出文件夹
  - 提供重设版面按钮，可清空文件夹并恢复按名称排序

- **窗口与快捷键**
  - 全局 `Cmd + L` 切换显示
  - `Cmd + W` 隐藏窗口
  - `Cmd + Q` 退出程序
  - `Esc` 会根据当前状态清除搜索、关闭文件夹、退出编辑或隐藏窗口

- **图标处理流程**
  - 先解析 symlink，再读取真实 App bundle 图标
  - 当 `NSWorkspace` 只返回 generic app icon 时，会继续读取 bundle metadata
  - 如果 bundle 没有可用图标，会自动生成 initials fallback icon
  - 通过异步缓存保持分页、拖拽和文件夹预览流畅

## 项目结构

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

## 核心组件

- **`LaunchpadViewModel`**
  - 管理扫描到的 App、文件夹与显示顺序
  - 用 `UserDefaults` 持久化排序和文件夹结构
  - 预加载相邻页面的 icon

- **`AppScannerService`**
  - 从系统、用户和 Homebrew 位置扫描 `.app`
  - 从 `Info.plist` 提取显示名称与 bundle identifier
  - 使用稳定标识去重

- **`AppIconResolver`**
  - 解析 canonical bundle path
  - 识别 generic `NSWorkspace` icon
  - 读取 `CFBundleIconFile`、`CFBundleIconName` 等 icon metadata
  - 在没有可用图标时生成 fallback icon

- **`AppIconCache`**
  - 用解析后的 bundle path 作为缓存键
  - 异步加载主界面、文件夹预览和拖拽浮层图标

## 系统要求

- macOS 15.6 或更高版本
- Xcode 17 或更高版本

## 编译

1. 克隆仓库：

   ```bash
   git clone https://github.com/EricYang801/Launchpad_Back.git
   cd Launchpad_Back
   ```

2. 用 Xcode 打开：

   ```bash
   open Launchpad_Back.xcodeproj
   ```

3. 运行：
  - 选择 `My Mac`
  - 按 `Cmd + R`

也可以直接在 Terminal 里编译：

```bash
xcodebuild build -scheme Launchpad_Back -destination 'platform=macOS'
```

## 测试

运行单元测试：

```bash
xcodebuild test -scheme Launchpad_Back -destination 'platform=macOS' -only-testing:Launchpad_BackTests
```

当前测试覆盖：
- 直接 bundle path 的 icon 解析
- symlink bundle 的 icon 解析
- metadata icon fallback
- 自动生成 fallback icon
- canonical bundle path 的 cache reuse
- 文件夹创建与恢复
- 重设版面
- 搜索与分页

## 使用方式

### 基本流程

1. 按 `Cmd + L` 显示或隐藏启动器。
2. 点击 App 图标即可启动。
3. 在搜索栏输入文字即可过滤 App。
4. 使用方向键或拖拽手势切换页面。

### 编辑与文件夹

1. 长按任意项目进入编辑模式。
2. 把 App 拖到另一个 App 上即可创建文件夹。
3. 把 App 拖到已有文件夹上即可加入文件夹。
4. 打开文件夹后可以重命名或调整内部顺序。
5. 从展开的文件夹中把 App 拖出即可移出文件夹。
6. 使用重设版面按钮可清空文件夹并恢复按名称排序。

## 补充说明

- App identity 以 `bundleID` 为主，没有 `bundleID` 的 App 会退回到安装路径。
- 排序和文件夹配置会保存在：
  - `launchpad_item_order`
  - `launchpad_folders`
- 如果某些 App 最终仍然只暴露 generic icon，Launchpad_Back 会显示一致的 fallback icon，而不是虚线 placeholder。

## 许可证

本项目采用 GPL-3.0。详见 [LICENSE](./LICENSE)。
