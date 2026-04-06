# Launchpad_Back

> A native Launchpad replacement for macOS 15.6+, built with SwiftUI + AppKit.

<div align="center">
  <img src="https://img.shields.io/github/downloads/EricYang801/Launchpad_Back/total?style=for-the-badge&color=blue" alt="Downloads" />
</div>

**[English](./README.md) | [繁體中文](./README_zh-TW.md) | [简体中文](./README_zh-CN.md)**

Looking for a Launchpad alternative on macOS Tahoe? This project focuses on exactly that: a launcher with global hotkey toggle, paged app grid, folder management, drag sorting, and fast local search.

## Demo
![Main Interface](./Example.png)

## Search Keywords

Launchpad alternative, macOS app launcher, SwiftUI launcher, AppKit launcher, global hotkey launcher, macOS Tahoe Launchpad replacement, Homebrew Cask app scanner

## What It Does (Aligned With Current Code)

- Runs in a floating launcher window and can be toggled globally with `Cmd + L`
- Uses a responsive grid with dynamic rows/columns (5-9 columns, 3-7 rows)
- Supports drag reorder, folders, folder rename, and drag-out from expanded folders
- Searches by app name, bundle ID, and app path (case-insensitive)
- Scans system, user, and Homebrew app locations
- Resolves app icons through workspace icon, metadata fallback, and generated fallback icon

## Controls

| Input | Behavior |
| --- | --- |
| `Cmd + L` | Toggle launcher visibility globally |
| `Cmd + W` | Hide launcher window |
| `Cmd + Q` | Quit app |
| `Esc` | Exit edit mode -> close folder -> clear search -> hide window |
| `Left` / `Up` | Previous page |
| `Right` / `Down` | Next page |
| Trackpad scroll gesture | Page switch with threshold and cooldown |
| Mouse wheel | Page switch with notch accumulation + debounce |

## App Discovery Paths

| Path | Recursive |
| --- | --- |
| `/System/Applications` | No |
| `/System/Applications/Utilities` | No |
| `/Applications` | No |
| `/Applications/Utilities` | No |
| `~/Applications` | No |
| `/opt/homebrew/Caskroom` | Yes |

The scanner also filters a set of hidden/background system apps and deduplicates apps using a stable identifier (`bundleID`, or path when `bundleID` is missing).

## Folder and Layout Behavior

- Long press any icon to enter edit mode
- Drag app onto app to create a folder (`New Folder` by default)
- Drag app onto folder to add it
- Reorder apps inside an expanded folder
- Drag app out of expanded folder to remove it
- Folder is removed automatically if only one app remains
- Reset layout clears saved custom order and folders, then restores alphabetical order

## Icon Pipeline

- Resolve symlink/canonical bundle path first
- Use `NSWorkspace` icon if it is not the generic app icon
- If generic icon is returned, load icon from bundle metadata (`CFBundleIconFile`, `CFBundleIconName`, etc.)
- If metadata icon is still unavailable, generate a consistent initials-based fallback icon
- Cache resized icons asynchronously and preload adjacent pages for smoother pagination

## Persistence

Launchpad_Back stores layout state in `UserDefaults`:

- `launchpad_item_order`
- `launchpad_folders`

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

## Requirements

- macOS 15.6 or later
- Xcode 26.0 or later

## Build

1. Clone the repository:

   ```bash
   git clone https://github.com/EricYang801/Launchpad_Back.git
   cd Launchpad_Back
   ```

2. Open in Xcode:

   ```bash
   open Launchpad_Back.xcodeproj
   ```

3. Build and run:

- Select `My Mac`
- Press `Cmd + R`

Or build from Terminal:

```bash
xcodebuild build -scheme Launchpad_Back -destination 'platform=macOS'
```

## Tests

Run unit tests:

```bash
xcodebuild test -scheme Launchpad_Back -destination 'platform=macOS' -only-testing:Launchpad_BackTests
```

Current test suite covers:

- icon resolution for direct path, symlink path, metadata fallback, and generated fallback icons
- icon cache behavior for canonical paths, concurrent requests, and in-flight async request joining
- folder creation/add/remove/delete and saved-order restore
- reset layout behavior
- search matching by app name, bundle ID, and path
- pagination slicing, bounds checks, and page validation
- basic `SearchViewModel` behavior

## License

This project is licensed under GPL-3.0. See [LICENSE](./LICENSE).
