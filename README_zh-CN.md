# Launchpad_Back (简体中文)

## 描述

这是一个使用 SwiftUI 开发的 macOS 应用程序，因为 macOS 26 Tahoe 的启动台被移除，为了使用方便，就写了这个 App，模拟原本启动台的功能，包含搜索、浏览和启动已安装的应用程序，提供熟悉的网格布局和分页界面。

![示例](./Example.png)

## 主要功能

*   **应用程序探索**：自动扫描并显示来自标准 macOS 目录 (`/Applications`, `/System/Applications`, `/System/Applications/Utilities`) 的所有应用程序。
*   **网格布局与分页**：将应用程序整齐地排列在网格中。如果应用程序数量超过单一屏幕的容量，会自动整理成多个页面。
*   **流畅的导航**：用户可以通过多种方式在页面之间切换：
    *   在触控板上使用双指滑动收拾。
    *   使用鼠标点击并拖拽。
    *   使用左、右方向键。
*   **即时搜索**：顶部的搜索栏让用户可以依名称即时筛选应用程序。
*   **视觉风格**：采用了模仿原生 macOS Launchpad 的模糊半透明背景效果（有想办法做得像 Liquid Glass 的效果但太难了）。
*   **键盘快捷键**：
    *   `Cmd + W`：关闭 Launchpad 窗口。
    *   `Cmd + Q`：结束应用程序。
    *   `Esc`：清除搜索内容，或在搜索框为空时关闭窗口。
    *   `方向键`：切换页面。
*   **性能优化**：
    *   应用程序扫描在后台线程中进行，以保持 UI 的流畅响应。
    *   应用程序图标被异步加载并进行缓存。

## 运作原理

*   **`LaunchpadViewModel`**：这是应用程序的逻辑核心。它负责寻找所有的 `.app` 套件，解析其 `Info.plist` 以获取元数据（如名称和 Bundle ID），处理重复的项目，并将最终的应用程序列表提供给视图。
*   **`ContentView`**：此文件包含了构成用户界面的所有 SwiftUI 视图。
    *   `LaunchpadView`：组合所有其他组件的主视图。
    *   `PageView`：代表网格中的单一页面。
    *   `AppIcon`：用于显示单个应用程序图标及其名称的视图。
    *   `SearchBar`：搜索组件。
    *   `PageIndicator`：底部用于指示当前页面的圆点。
*   **手势与事件处理**：应用程序结合了 `DragGesture`（用于鼠标拖拽）、一个自定义的 `NSViewRepresentable` (`TouchpadScrollView`，用于侦测触控板滚动），以及 `NSEvent.addLocalMonitorForEvents`（用于监听全局键盘事件）。
