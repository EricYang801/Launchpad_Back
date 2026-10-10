# Launchpad_Back — 在 macOS Tahoe (26) 上找回经典启动台 Launchpad

> 让 Launchpad 回到 macOS 26 Tahoe：全屏应用网格、分页、文件夹、拖拽排列，免费开源。

**[English](./README.md) | [繁體中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

<div align="center">
  <a href="https://github.com/EricYang801/Launchpad_Back/releases/latest">
    <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="下载次数" />
  </a>
  <br /><br />
  <strong><a href="https://github.com/EricYang801/Launchpad_Back/releases/latest">⬇ 下载最新版本</a></strong>
  <br /><br />
  <img src="./Example.png" alt="Launchpad_Back 在 macOS Tahoe 上的界面：模糊桌面壁纸上的全屏 Launchpad 启动台应用网格、文件夹和分页圆点" />
</div>

## 为什么做这个

Apple 在 macOS 26 Tahoe 中移除了启动台（Launchpad），改用聚焦搜索（Spotlight）里的“App”视图代替。如果你怀念那个熟悉的全屏图标网格——左右滑动翻页、把应用归进文件夹、按自己的习惯摆放——Launchpad_Back 就是来把它找回来的。这是一个用 SwiftUI + AppKit 编写的原生应用，基于 GPL-3.0 协议免费开源。

## 功能

- **和原版一样全屏**：在鼠标指针所在的显示器上铺满整个屏幕，背景是模糊并调暗的桌面壁纸（获取不到时使用系统模糊材质），打开和关闭都有缩放淡入淡出动画。
- **分页图标网格**：默认 7 列 × 5 行，与原版启动台一致；可在设置中调整列数（4–12）和行数（3–9）。底部的分页圆点可以直接点击。
- **顺手的翻页方式**：触控板双指滑动时页面跟随手指并自动吸附；鼠标滚轮每滚一格翻一页；在空白处按住拖动也能翻页；方向键同样可用。
- **Big Sur 风格文件夹**：半透明图块预览 9 个应用。把一个应用拖到另一个应用上即可创建文件夹，并根据 App Store 分类自动命名（例如“开发者工具”“游戏”），同时自动打开方便你直接改名。点击文件夹标题即可重命名，把应用拖出文件夹即可移除。文件夹只剩一个应用时会自动变回该应用。超过 15 个应用的文件夹会分页显示。
- **编辑模式**：长按图标或直接开始拖动即可进入。图标会抖动，拖动时其他图标实时让位；把图标停在屏幕边缘即可移到其他页。点击空白处或按 `Esc` 结束。
- **打字即搜索**：直接开始输入即可。会匹配本地化的应用名称、英文名称、bundle ID 和路径，名称开头匹配的结果排在最前。用方向键移动选择，按 `Return` 打开。
- **全局快捷键**：默认 `⌘L`，可在设置中重新录制。`F1`–`F20` 可以单独使用，设成 `F4` 就和以前的启动台按键一样。
- **触控板捏合**：拇指与三指合拢即可打开启动台，张开即可关闭，和原版手势一样。只有正好四指才会触发，五指捏合留给 macOS（见下方常见问题）。
- **触发角**：把指针移到你选择的屏幕角落，即可显示或隐藏启动台。
- **拖到程序坞**：程序坞会像原版一样显示在启动台上方，把应用拖上去即可添加到程序坞。
- **找到你所有的应用**：`/System/Applications`（含“实用工具”）、`/Applications` 及其子文件夹（例如 Adobe 全家桶）、`~/Applications`，以及 Apple 芯片（`/opt/homebrew`）和 Intel（`/usr/local`）上的 Homebrew Caskroom。每次打开都会重新扫描，新安装或已删除的应用会立即反映。
- **保留你的布局**：顺序和文件夹都保存在本地。暂时找不到的应用（例如放在未连接的移动硬盘上）会保留原来的位置，回来后自动归位。2.x 版本的布局会自动迁移。
- **内存占用极低**：安装约 150 个应用时仅占用约 40 MB 内存。图标按实际显示尺寸生成，搜索结果每个关键词只计算一次，重新扫描没有变化时也不会重绘界面。
- **多语言界面**：英文、繁体中文、简体中文。

## 安装

1. 从 **[最新版本](https://github.com/EricYang801/Launchpad_Back/releases/latest)** 下载 `Launchpad_Back.app.zip`。
2. 解压。
3. 把 `Launchpad_Back.app` 移到“应用程序”文件夹（`/Applications`）。
4. 打开应用，然后按 `⌘L`（或点击程序坞图标）呼出启动台。

### 系统要求

- macOS 15.6 或更高版本（支持 macOS 26 Tahoe）
- Apple 芯片或 Intel 处理器的 Mac

### 首次打开

本应用使用 ad-hoc 签名，未经 Apple 公证（notarization），因此第一次打开时会被 macOS 拦截。任选一种方式处理：

- 在 `Launchpad_Back.app` 上右键（或按住 Control 点按）→“**打开**”，再确认一次；或
- 先尝试打开一次，然后前往“**系统设置 → 隐私与安全性**”，点击“**仍要打开**”。

只需要操作一次。

## 使用方法

| 操作 | 方式 |
| --- | --- |
| 显示／隐藏启动台 | 全局快捷键（默认 `⌘L`）、拇指与三指合拢（张开即关闭）、触发角、点击程序坞图标，或再次打开应用 |
| 打开应用 | 点击图标 |
| 翻页 | 双指滑动、鼠标滚轮、在空白处按住拖动、`←` / `→`，或点击分页圆点 |
| 搜索 | 直接打字；`↑` `↓` `←` `→` 移动选择，`Return` 打开 |
| 进入编辑模式 | 长按图标，或直接拖动图标 |
| 把应用移到其他页 | 拖动图标并停在屏幕左右边缘 |
| 创建文件夹 | 把应用拖到另一个应用上 |
| 重命名文件夹 | 点击文件夹标题 |
| 把应用移出文件夹 | 从打开的文件夹中拖出来 |
| 把应用添加到程序坞 | 把图标拖到程序坞上 |
| 后退一步 | `Esc`：取消拖动 → 关闭文件夹 → 退出编辑模式 → 清空搜索 → 关闭启动台 |
| 关闭启动台 | 打开应用、点击空白处、切换到其他应用，或按 `⌘W` |
| 打开设置 | `⌘,` |
| 退出应用 | `⌘Q` |

## 设置

在启动台打开时按 `⌘,`。

<img src="./Settings.png" alt="Launchpad_Back 设置窗口：全局快捷键、登录时打开、在程序坞中显示、网格列数和行数、重置布局" width="450" />

- **快捷键**：点击按钮后按下新的组合键。普通按键需要配合 `⌘`、`⌥` 或 `⌃`；`F1`–`F20` 可以单独使用。
- **用拇指和三指捏合**：默认开启。
- **触发角**：默认关闭，可选左上角、右上角、左下角或右下角。
- **登录时打开**：登录 Mac 时自动启动 Launchpad_Back。
- **在程序坞中显示**：关闭后即可隐藏程序坞图标。
- **网格**：列数（4–12）和行数（3–9）。
- **重置布局**：清除自定义顺序和文件夹。

## 常见问题

### macOS Tahoe 的启动台去哪了？

Apple 在 macOS 26 Tahoe 中移除了启动台，改由聚焦搜索里的“App”视图代替。它会列出应用，但没有可以自由摆放的分页和文件夹。

### 怎么在 macOS 26 上找回启动台？

从 [最新版本](https://github.com/EricYang801/Launchpad_Back/releases/latest) 安装 Launchpad_Back，首次打开时允许运行（见[首次打开](#首次打开)），然后按 `⌘L`。在设置中开启“登录时打开”，它就会一直待命。

### 能像以前一样用 F4 打开启动台吗？

可以。按 `⌘,` 打开设置，点击快捷键按钮后按 `F4` 即可。`F1`–`F20` 不需要配合修饰键。很多 Mac 键盘需要同时按住 `fn`，或在“系统设置 → 键盘”中开启“将 F1、F2 等键用作标准功能键”。

### 我的文件夹会保留吗？

会。顺序和文件夹都保存在本地，重启或更新后依然存在。Launchpad_Back 2.x 版本的布局会自动迁移。不过它不会导入 Apple 旧版启动台的布局。

### 捏合时 macOS 的“App”界面也弹出来，或变成显示桌面

macOS 自己的“App”界面也使用拇指与三指合拢（张开则是显示桌面）。Launchpad_Back 只对正好四指有反应，所以请关闭系统的四指捏合，五指捏合留给 macOS。如果“系统设置 → 触控板 → 更多手势”里的开关关不掉，可以在“终端”中运行：

```bash
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 0
killall Dock
```

运行后注销再重新登录。可以用 `defaults read com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture` 确认（`0` 表示关闭）。想恢复的话，把命令里的 `-int 0` 改成 `-int 2` 再运行一次。

### 需要授予什么权限吗？

不需要。全局快捷键使用 Carbon hot key 机制，触发角只检测指针移动，捏合手势在本机读取触控板的触摸数据，都无需开启“辅助功能”权限。所有数据都留在你的 Mac 上。

### 这是 Apple 官方应用吗？

不是。Launchpad_Back 是独立的开源项目，与 Apple 没有任何关联，也未获 Apple 认可。“Launchpad”和“macOS”是 Apple Inc. 的商标。

## 从源码构建

需要 Xcode 26。

```bash
git clone https://github.com/EricYang801/Launchpad_Back.git
cd Launchpad_Back
open Launchpad_Back.xcodeproj   # 然后按 ⌘R
```

或者在“终端”中：

```bash
xcodebuild build -scheme Launchpad_Back -destination 'platform=macOS'
```

运行单元测试：

```bash
xcodebuild test -scheme Launchpad_Back -destination 'platform=macOS' -only-testing:Launchpad_BackTests
```

## 参与贡献

欢迎提交问题反馈、建议和 Pull Request；较大的改动请先[创建 issue](https://github.com/EricYang801/Launchpad_Back/issues) 讨论。

```text
Launchpad_Back/
├── App/        App delegate、窗口控制器、输入处理、全局快捷键
├── Model/      数据存储、布局、网格尺寸、偏好设置
├── Services/   应用扫描、图标缓存、桌面壁纸
├── Views/      SwiftUI 视图
└── Localizable.xcstrings   英文、繁体中文、简体中文字符串
```

## 许可证

[GPL-3.0](./LICENSE) © [EricYang801](https://github.com/EricYang801)

Launchpad_Back 与 Apple Inc. 没有任何关联。
