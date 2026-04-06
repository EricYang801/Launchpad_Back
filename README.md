# Launchpad_Back

> A SwiftUI-based replacement for Launchpad on modern macOS.

<div align="center">
  <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="Downloads" />
</div>

**[English](./README.md) | [繁體中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

## Demo
![Main Interface](./Example.png)

## Overview

Launchpad_Back recreates a Launchpad-style app launcher for macOS 15.6 and later. It scans common application locations, presents apps in a paged grid, supports folders and drag reordering, and runs as a floating window that can be toggled globally with `Cmd + L`.

This project exists because Apple removed Launchpad in macOS 26 Tahoe. Launchpad_Back keeps the familiar workflow while staying native to SwiftUI and AppKit.

## Features

- **App discovery**
  - Scans `/Applications`
  - Scans `/System/Applications`
  - Scans `/System/Applications/Utilities`
  - Scans the user Applications directory
  - Recursively scans Homebrew Cask installs under `/opt/homebrew/Caskroom`

- **Launchpad-style navigation**
  - Responsive paged grid layout
  - Mouse drag and arrow-key pagination
  - Trackpad gesture handling through the event manager layer
  - Search with instant filtering

- **Organization**
  - Drag apps to reorder
  - Drag app onto app to create a folder
  - Drag app onto folder to add it
  - Reorder apps inside expanded folders
  - Remove apps from folders by dragging them out
  - Reset layout button to restore alphabetical order and clear folders

- **Window and shortcuts**
  - Global `Cmd + L` to toggle visibility
  - `Cmd + W` to hide the window
  - `Cmd + Q` to quit
  - `Esc` to clear search, close folder, exit edit mode, or hide window

- **Icon pipeline**
  - Resolves symlinked app bundles before loading icons
  - Falls back to bundle metadata lookup when `NSWorkspace` only returns a generic app icon
  - Generates a custom initials-based icon when no usable bundle icon exists
  - Uses async caching to keep scrolling and drag interactions smooth

## Project Structure

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

## Key Components

- **`LaunchpadViewModel`**
  - Owns scanned apps, folders, and display order
  - Persists order and folder structure in `UserDefaults`
  - Preloads adjacent-page icons for smoother page changes

- **`AppScannerService`**
  - Scans app bundles from system, user, and Homebrew locations
  - Extracts display name and bundle identifier from `Info.plist`
  - Deduplicates apps with a stable identifier

- **`AppIconResolver`**
  - Resolves canonical bundle paths
  - Detects generic `NSWorkspace` icons
  - Loads `CFBundleIconFile`, `CFBundleIconName`, and related metadata resources
  - Generates fallback icons for apps with no usable bundle image

- **`AppIconCache`**
  - Caches resized `NSImage` instances by resolved bundle path
  - Loads icons asynchronously for grid, folder preview, and floating drag overlays

## Requirements

- macOS 15.6 or later
- Xcode 17 or later

## Build

1. Clone the repository:

   ```bash
   git clone https://github.com/EricYang801/Launchpad_Back.git
   cd Launchpad_Back
   ```

2. Open the project in Xcode:

   ```bash
   open Launchpad_Back.xcodeproj
   ```

3. Build and run:
  - Select `My Mac`
  - Press `Cmd + R`

You can also build from Terminal:

```bash
xcodebuild build -scheme Launchpad_Back -destination 'platform=macOS'
```

## Tests

Run the unit test target with:

```bash
xcodebuild test -scheme Launchpad_Back -destination 'platform=macOS' -only-testing:Launchpad_BackTests
```

Current tests cover:
- icon resolution for direct bundles
- icon resolution for symlinked bundles
- metadata icon fallback
- generated fallback icons
- cache reuse for canonical bundle paths
- folder creation and restoration
- reset layout
- search and pagination

## Usage

### Basic flow

1. Press `Cmd + L` to show or hide the launcher.
2. Click an app to launch it.
3. Type in the search bar to filter apps.
4. Use the arrow keys or drag gesture to switch pages.

### Editing and folders

1. Long press an item to enter edit mode.
2. Drag an app onto another app to create a folder.
3. Drag an app onto an existing folder to insert it.
4. Open a folder to rename it or reorder its contents.
5. Drag an app out of an expanded folder to remove it.
6. Use the reset layout button to clear folders and restore alphabetical order.

## Notes

- App identity is based on `bundleID`, with install path used as fallback for apps that do not provide one.
- Folder and item order are persisted with:
  - `launchpad_item_order`
  - `launchpad_folders`
- If an app bundle still exposes only a generic icon, Launchpad_Back now generates a consistent fallback icon instead of showing a dashed placeholder.

## License

This project is licensed under GPL-3.0. See [LICENSE](./LICENSE).
