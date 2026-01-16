# Launchpad_Back

> A macOS application developed with SwiftUI, designed to mimic the native macOS Launchpad functionality

<div align="center">
  <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="下載次數" />
</div>

**[English](./README.md) | [繁體中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

## Demo
![Main Interface](./Example.png)

## Overview

Launchpad_Back is a macOS application built with SwiftUI, providing an alternative to the Launchpad feature that was removed in macOS 26 Tahoe by Apple.

**Status**: Feature-complete | **Platform**: macOS 15+ | **Language**: Swift/SwiftUI

## Main Features

### Core Features
- **App Search**: Automatically scans and displays all applications from the following locations:
  - `/Applications`
  - `/System/Applications`
  - `/System/Applications/Utilities`
  - User application directories
  - Homebrew Cask applications

- **Grid Layout**:
  - Neat grid arrangement of app icons
  - Automatic pagination

- **Multiple Gestures & Shortcuts**:
  - Two-finger swipe gesture on trackpad
  - Mouse click and drag gesture
  - Arrow keys for page navigation
  - Keyboard shortcut support

### User Interface
- **Native-like Design**:
  - Dark theme with blurred, translucent background
  - Inspired by native macOS Launchpad aesthetics
  - Smooth animations and transitions

- **⌨ Keyboard Shortcuts**:
  - `Cmd + L`: Toggle Launchpad visibility (global hotkey)
  - `Cmd + W`: Close Launchpad window
  - `Cmd + Q`: Quit application
  - `Esc`: Clear search or close window
  - `Arrow keys`: Navigate between pages

### Performance & Reliability
- **Background Processing**: App scanning runs on background threads to keep the UI responsive
- **Caching**: App icons are loaded asynchronously and cached for faster access
- **Error Handling**: Comprehensive error handling and logging
- **Auto-Save**: Saves app order and folder configuration

### Advanced Features
- **Folder Organization**: Group apps into custom folders
- **Drag & Drop Support**: Reorganize apps and create folders via drag gestures
- **Edit Mode**: Manage app organization and folders
- **Duplicate Handling**: Prevents duplicate apps from appearing

## Architecture

### Project Structure

```
Launchpad_Back/
├── Models/
│   └── AppItem.swift              # App data model
├── Services/
│   ├── AppScannerService.swift    # App discovery and scanning
│   ├── AppLauncherService.swift   # App launching
│   ├── AppIconCache.swift         # Icon caching and management
│   ├── KeyboardEventManager.swift # Global keyboard event handling
│   ├── GestureManager.swift       # Gesture recognition and handling
│   ├── GridLayoutManager.swift    # Grid layout calculation
│   └── Logger.swift               # App logging
├── ViewModels/
│   ├── LaunchpadViewModel.swift   # Main app state management
│   ├── SearchViewModel.swift      # Search functionality
│   ├── PaginationViewModel.swift  # Page navigation logic
│   └── EditModeManager.swift      # Edit mode state management
├── Views/
│   ├── ContentView.swift          # Main UI container
│   ├── LaunchpadView.swift        # Main view arrangement
│   ├── PageView.swift             # Single page display
│   ├── AppIconView.swift          # App icon component
│   ├── SearchBarView.swift        # Search interface
│   ├── PageIndicatorView.swift    # Page indicator dots
│   ├── TouchpadScrollView.swift   # Trackpad scroll handling
│   ├── FolderExpandedView.swift   # Folder expanded UI
│   ├── BackgroundView.swift       # Background styling
│   └── ...
└── Assets/                        # Images and app icons
```

### Key Components

#### **LaunchpadViewModel**
- Core app state management
- Handles app discovery and folder operations
- Manages display item order
- Coordinates between services and views

```swift
@Published var apps: [AppItem]
@Published var folders: [AppFolder]
@Published var displayItems: [LaunchpadDisplayItem]
@Published var isLoading: Bool
```

#### **AppScannerService**
- Scans system directories for `.app` bundles
- Extracts metadata from `Info.plist` files
- Handles duplicate detection and filtering
- Supports multiple search paths:
  - System apps
  - User apps
  - Homebrew Cask

#### **AppLauncherService**
- Launches apps by path or bundle identifier
- Supports synchronous and asynchronous launching
- Gracefully handles launch failures

#### **KeyboardEventManager**
- Global keyboard event monitoring
- Handles arrow keys, Escape, and modifier combinations
- Uses Cmd+L to toggle window visibility

#### **GestureManager**
- Manages mouse drag gestures
- Handles trackpad scroll detection
- Supports cross-page and cross-folder dragging

#### **AppIconCache**
- Asynchronous icon loading
- NSImage caching and retrieval
- Falls back to app name display if icon unavailable

## Installation & Build Instructions

### System Requirements
- **macOS**: 15.0 or later

### Installation & Build

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/Launchpad_Back.git
   cd Launchpad_Back
   ```

2. **Open the project in Xcode**:
   ```bash
   open Launchpad_Back.xcodeproj
   ```

3. **Build and Run**:
   - Select your Mac as the target device
   - Press `Cmd + R` to build and run
   - Or use Product → Run from the menu

### Install as Application

After building, you can install the application:

1. Find the generated `.app` in Xcode's build directory
2. Copy it to `/Applications`
3. Launch from the Applications folder or via Spotlight

## User Guide

### Basic Operations

1. **Launch an app**:
   - Click any app icon to launch
   - Click a folder icon to expand and view contents

2. **Search for apps**:
   - Click the search bar or start typing
   - Results are filtered in real time
   - Press `Esc` to clear search

3. **Navigate between pages**:
   - Use arrow keys to move between pages
   - Swipe with two fingers on the trackpad
   - Click and drag with the mouse

4. **Edit app order**:
   - Enter edit mode via button
   - Drag apps to rearrange
   - Drag apps onto each other to create folders

### Global Hotkeys

- **`Cmd + L`**: Toggle Launchpad visibility from any app

## Technical Details

### Data Models

#### **AppItem**
```swift
struct AppItem: LaunchpadItem {
    let id: UUID
    let name: String
    let bundleID: String
    let path: String
    let isSystemApp: Bool
    var displayOrder: Int
}
```

#### **LaunchpadDisplayItem** (enum)
```swift
enum LaunchpadDisplayItem {
    case app(AppItem)
    case folder(AppFolder)
}
```

#### **AppFolder**
```swift
struct AppFolder: LaunchpadItem {
    let id: UUID
    var name: String
    var apps: [AppItem]
    var displayOrder: Int
}
```

### State Management

The app uses the MVVM pattern and Combine framework:
- `@StateObject` for ViewModel lifecycle management
- `@EnvironmentObject` for state sharing across views
- `@Published` for reactive state updates
- `ObservableObject` protocol for view synchronization

### Persistence

App state is persisted using `UserDefaults`:
- **launchpad_item_order**: Order of displayed items
- **launchpad_folders**: Folder definitions and contents

## Known Issues & Limitations

- Only supports apps with valid `.app` bundles
- Custom folder icons are not currently supported

## License

This project is licensed under the GPL-3.0 License. See the [LICENSE](./LICENSE) file for details.

## Author

**Eric_Yang**
- Created: June 2025
- Last updated: January 2026

## Issues or Suggestions
If you have any questions or suggestions, feel free to open an issue or pull request on GitHub!
