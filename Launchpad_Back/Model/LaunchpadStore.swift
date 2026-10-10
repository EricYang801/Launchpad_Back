import AppKit
import SwiftUI

/// An icon being dragged, and where it would land if dropped now.
struct DragState {
    var item: LaunchItem
    /// Set when the drag started inside an open folder.
    var sourceFolder: UUID?
    /// The folder was left, so the drop goes to the main grid.
    var leftFolder = false
    /// Insertion index in the grid the icon is over, counted without the dragged icon.
    var index: Int
    /// The icon to merge into: dropping an app here makes a folder or adds to one.
    var mergeTarget: String?
}

/// All of Launchpad's state. Views read it; gestures, keys and the window controller call into it.
@Observable
final class LaunchpadStore {
    private(set) var apps: [String: AppItem] = [:]
    private(set) var items: [LaunchItem] = []
    private(set) var layout: Layout

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            if !query.isEmpty {
                openFolderID = nil
                isEditing = false
            }
            page = 0
            selection = 0
            pageOffset = 0
        }
    }
    private(set) var page = 0
    /// Live horizontal offset while a swipe follows the fingers.
    private(set) var pageOffset: CGFloat = 0
    var isEditing = false
    /// A folder name is being edited, so arrow and return keys belong to the text field.
    @ObservationIgnored var isRenaming = false
    private(set) var openFolderID: UUID?
    private(set) var folderPage = 0
    /// Keyboard selection among search results.
    private(set) var selection = 0
    private(set) var drag: DragState?
    /// Kept apart from `drag` so pointer movement only redraws the floating icon, not the whole grid.
    private(set) var dragLocation: CGPoint = .zero
    /// Drives the open/close zoom; the window controller orders the window out after it.
    var isPresented = false
    var size: CGSize = .zero
    var dock = DockPlacement()
    var backdrop: NSImage?

    let preferences: Preferences
    /// Hides the Launchpad window.
    @ObservationIgnored var dismiss: () -> Void = {}
    /// Starts a system drag of the app so it can be dropped on the Dock; returns false if it couldn't start.
    @ObservationIgnored var dragToDock: (AppItem) -> Bool = { _ in false }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let scanner: AppScanner
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    @ObservationIgnored private var reorderTask: Task<Void, Never>?
    @ObservationIgnored private var pendingIndex: Int?
    @ObservationIgnored private var edgeTask: Task<Void, Never>?
    @ObservationIgnored private var edgeDirection = 0
    /// A click that ends a drag must not also launch or open the icon.
    @ObservationIgnored private var lastDragEnd = Date.distantPast
    @ObservationIgnored private var searchCache: (query: String, results: [AppItem])?
    @ObservationIgnored private var itemsVersion = 0
    @ObservationIgnored private var gridCache: (key: GridKey, items: [LaunchItem])?
    /// The current drag became a system drag towards the Dock; ignore the rest of the gesture.
    @ObservationIgnored private var handedOffToDock = false

    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.86)

    init(preferences: Preferences = .shared, defaults: UserDefaults = .standard, scanner: AppScanner = .standard) {
        self.preferences = preferences
        self.defaults = defaults
        self.scanner = scanner
        layout = Layout.load(from: defaults)
    }

    // MARK: - Content

    /// Rescans installed apps; called every time Launchpad opens so new and removed apps show up.
    func reload() async {
        if let reloadTask { return await reloadTask.value }
        let task = Task {
            let scanned = await Task.detached(priority: .userInitiated) { [scanner] in scanner.scan() }.value
            setApps(scanned)
        }
        reloadTask = task
        await task.value
        reloadTask = nil
    }

    func setApps(_ scanned: [AppItem]) {
        let scannedApps = Dictionary(scanned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Launchpad rescans on every open; nothing installed or removed means nothing to redraw.
        guard scannedApps != apps else { return }
        apps = scannedApps
        searchCache = nil
        gridCache = nil
        let before = layout
        layout.place(apps)
        if layout != before { layout.save(to: defaults) }
        withAnimation(Self.spring) { refreshItems() }
    }

    func resetLayout() {
        layout = Layout()
        commit { _ in }
    }

    private func commit(_ change: (inout Layout) -> Void) {
        change(&layout)
        layout.place(apps)
        layout.save(to: defaults)
        refreshItems()
    }

    private func refreshItems() {
        items = layout.items(for: apps)
        itemsVersion += 1
        page = min(page, pageCount - 1)
        if openFolderID != nil, openFolder == nil { openFolderID = nil }
    }

    // MARK: - Derived

    var metrics: GridMetrics {
        .main(in: size, columns: preferences.columns, rows: preferences.rows, dock: dock)
    }

    /// The window area not covered by the Dock.
    var contentArea: CGRect { dock.contentArea(in: size) }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Memoized: a single redraw reads the results several times (grid, page count, empty state, keyboard).
    var searchResults: [AppItem] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let apps = apps
        guard !needle.isEmpty else { return [] }
        if let searchCache, searchCache.query == needle { return searchCache.results }

        let results = apps.values
            .filter { $0.searchKey.contains(needle) }
            .map { (app: $0, isPrefix: $0.name.lowercased().hasPrefix(needle)) }
            .sorted { lhs, rhs in
                if lhs.isPrefix != rhs.isPrefix { return lhs.isPrefix }
                return lhs.app.name.localizedStandardCompare(rhs.app.name) == .orderedAscending
            }
            .map(\.app)
        searchCache = (needle, results)
        return results
    }

    /// What the main grid shows: search results, or the layout with a dragged icon at its prospective spot.
    /// Memoized: during a drag it is read several times per pointer move (grid, page count, drop target).
    var gridItems: [LaunchItem] {
        let items = items, drag = drag
        let movingInGrid = drag.map { $0.sourceFolder == nil || $0.leftFolder } ?? false
        let key = GridKey(
            version: itemsVersion,
            query: isSearching ? query : "",
            dragID: movingInGrid ? drag?.item.id : nil,
            dragIndex: movingInGrid ? drag?.index ?? 0 : 0
        )
        if let gridCache, gridCache.key == key { return gridCache.items }

        let list: [LaunchItem]
        if isSearching {
            list = searchResults.map(LaunchItem.app)
        } else if movingInGrid, let drag {
            var moved = items.filter { $0.id != drag.item.id }
            moved.insert(drag.item, at: min(drag.index, moved.count))
            list = moved
        } else {
            list = items
        }
        gridCache = (key, list)
        return list
    }

    private struct GridKey: Equatable {
        var version: Int
        var query: String
        var dragID: String?
        var dragIndex: Int
    }

    var pageCount: Int {
        // While dragging, offer one more page so an icon can move onto a new page.
        metrics.pageCount(for: gridItems.count + (drag == nil ? 0 : 1))
    }

    var openFolder: Folder? {
        guard let openFolderID else { return nil }
        for case .folder(let folder) in items where folder.id == openFolderID { return folder }
        return nil
    }

    /// Whether the open folder is on screen; it stays mounted but hidden while an icon is dragged out of it.
    var showsFolder: Bool { openFolderID != nil && drag?.leftFolder != true }

    func folderMetrics(for folder: Folder) -> GridMetrics {
        .folder(in: size, main: metrics, appCount: folder.apps.count)
    }

    func folderApps(_ folder: Folder) -> [AppItem] {
        guard let drag, drag.sourceFolder == folder.id, !drag.leftFolder, let app = drag.item.app else { return folder.apps }
        var list = folder.apps.filter { $0.id != app.id }
        list.insert(app, at: min(drag.index, list.count))
        return list
    }

    // MARK: - Actions

    func activate(_ item: LaunchItem) {
        guard drag == nil, Date().timeIntervalSince(lastDragEnd) > 0.3 else { return }
        switch item {
        case .app(let app): if !isEditing { launch(app) }
        case .folder(let folder): openFolder(folder.id)
        }
    }

    func launch(_ app: AppItem) {
        dismiss()
        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                NSApp.activate()
                NSAlert(error: error).runModal()
            }
        }
    }

    func launchSelection() {
        let results = searchResults
        guard results.indices.contains(selection) else { return }
        launch(results[selection])
    }

    func openFolder(_ id: UUID) {
        withAnimation(Self.spring) {
            openFolderID = id
            folderPage = 0
        }
    }

    func closeFolder() {
        withAnimation(Self.spring) { openFolderID = nil }
    }

    func rename(_ folderID: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        commit { $0.rename(folderID, to: name) }
    }

    func backgroundTapped() {
        if openFolderID != nil {
            closeFolder()
        } else if isEditing {
            withAnimation { isEditing = false }
        } else {
            dismiss()
        }
    }

    /// Escape backs out one level at a time, like Launchpad.
    func escape() {
        if drag != nil {
            cancelDrag()
        } else if openFolderID != nil {
            closeFolder()
        } else if isEditing {
            withAnimation { isEditing = false }
        } else if !query.isEmpty {
            query = ""
        } else {
            dismiss()
        }
    }

    /// Clears transient state each time Launchpad opens.
    func prepareForPresentation() {
        cancelDrag()
        handedOffToDock = false
        query = ""
        isEditing = false
        openFolderID = nil
        pageOffset = 0
    }

    // MARK: - Paging

    func goToPage(_ target: Int) {
        withAnimation(Self.spring) {
            if openFolderID != nil, let folder = openFolder {
                let count = folderMetrics(for: folder).pageCount(for: folder.apps.count)
                folderPage = min(max(target, 0), count - 1)
            } else {
                page = min(max(target, 0), pageCount - 1)
            }
            pageOffset = 0
        }
    }

    func movePage(by delta: Int) {
        goToPage((openFolderID != nil ? folderPage : page) + delta)
    }

    /// A swipe in progress; the page follows with rubber-banding past the first and last page.
    func swipeChanged(_ translation: CGFloat) {
        guard drag == nil, openFolderID == nil else { return }
        let width = max(size.width, 1)
        let atEdge = (translation > 0 && page == 0) || (translation < 0 && page == pageCount - 1)
        pageOffset = max(-width, min(width, atEdge ? translation * 0.25 : translation))
    }

    /// `velocity` is the extra distance the swipe would travel on its own, in points.
    func swipeEnded(_ translation: CGFloat, velocity: CGFloat) {
        guard drag == nil else { return }
        let threshold = min(size.width * 0.12, 80)
        if translation < -threshold || velocity < -150 {
            movePage(by: 1)
        } else if translation > threshold || velocity > 150 {
            movePage(by: -1)
        } else {
            withAnimation(Self.spring) { pageOffset = 0 }
        }
    }

    // MARK: - Keyboard

    enum Key { case left, right, up, down, enter }

    /// Returns false to let the key through (e.g. arrows to the search field when nothing applies).
    func handle(_ key: Key) -> Bool {
        if isSearching {
            let count = searchResults.count
            switch key {
            case .enter: launchSelection(); return true
            case .left: selection -= 1
            case .right: selection += 1
            case .up: selection -= metrics.columns
            case .down: selection += metrics.columns
            }
            selection = min(max(selection, 0), max(count - 1, 0))
            if selection / metrics.perPage != page { goToPage(selection / metrics.perPage) }
            return true
        }
        switch key {
        case .left, .up: movePage(by: -1)
        case .right, .down: movePage(by: 1)
        case .enter: return false
        }
        return true
    }

    // MARK: - Drag and drop

    func dragChanged(_ item: LaunchItem, from folderID: UUID?, to location: CGPoint) {
        guard !isSearching, !handedOffToDock else { return }
        if drag == nil {
            let index = folderID == nil
                ? items.firstIndex { $0.id == item.id }
                : openFolder?.apps.firstIndex { $0.id == item.id }
            withAnimation { isEditing = true }
            drag = DragState(item: item, sourceFolder: folderID, index: index ?? 0)
        }
        dragLocation = location
        // Like Launchpad, an app dragged onto the Dock is added there; the icon returns to its place here.
        if let app = item.app, dock.handoffZone(in: size).contains(location), dragToDock(app) {
            handedOffToDock = true
            cancelDrag()
            return
        }
        updateDropTarget()
    }

    /// The system drag towards the Dock finished, wherever it was dropped.
    func dockDragEnded() {
        handedOffToDock = false
        lastDragEnd = Date()
    }

    func endDrag() {
        guard let drag else { return }
        stopDragTimers()
        lastDragEnd = Date()
        let installed = Set(apps.keys)

        withAnimation(Self.spring) {
            if drag.leftFolder { openFolderID = nil }
            if let target = drag.mergeTarget, let app = drag.item.app {
                let targetApp = items.first { $0.id == target }?.app
                let name = FolderName.suggested(for: [targetApp, app].compactMap { $0 })
                var folderID: UUID?
                commit { folderID = $0.merge(app.id, into: target, newFolderName: name) }
                // Like Launchpad, a newly made folder opens so it can be renamed.
                if targetApp != nil, let folderID { openFolderID = folderID; folderPage = 0 }
            } else if let folderID = drag.sourceFolder, !drag.leftFolder {
                commit { $0.moveInFolder(folderID, app: drag.item.id, to: drag.index, installed: installed) }
            } else {
                commit { $0.move(drag.item.id, to: drag.index, installed: installed) }
            }
            self.drag = nil
        }
    }

    func cancelDrag() {
        stopDragTimers()
        withAnimation(Self.spring) { drag = nil }
    }

    private func stopDragTimers() {
        reorderTask?.cancel()
        edgeTask?.cancel()
        pendingIndex = nil
        edgeDirection = 0
    }

    private func updateDropTarget() {
        guard let drag else { return }

        if let folder = openFolder, drag.sourceFolder == folder.id, !drag.leftFolder {
            let grid = folderMetrics(for: folder)
            let bounds = grid.frame.insetBy(dx: -grid.cellSize.width * 0.4, dy: -grid.cellSize.height * 0.6)
            if bounds.contains(dragLocation) {
                if let slot = grid.slot(at: dragLocation) {
                    scheduleReorder(to: min(folderPage * grid.perPage + slot, folder.apps.count - 1))
                }
                return
            }
            // Dragged out of the folder: it closes and the icon continues over the main grid.
            reorderTask?.cancel()
            pendingIndex = nil
            withAnimation(Self.spring) {
                self.drag?.leftFolder = true
                self.drag?.index = items.count
            }
        }

        updateEdgeFlip()
        let grid = metrics
        let location = dragLocation
        guard let slot = grid.slot(at: location) else {
            setMergeTarget(nil)
            return
        }
        let list = gridItems
        let index = page * grid.perPage + slot
        if drag.item.app != nil, index < list.count, list[index].id != drag.item.id, grid.isOverIcon(location, slot: slot) {
            reorderTask?.cancel()
            pendingIndex = nil
            setMergeTarget(list[index].id)
            return
        }
        setMergeTarget(nil)
        scheduleReorder(to: min(index, max(list.count - 1, 0)))
    }

    /// Writes only real changes: every write to `drag` redraws the grid.
    private func setMergeTarget(_ id: String?) {
        if drag?.mergeTarget != id { drag?.mergeTarget = id }
    }

    /// Icons make room only after the pointer rests briefly, so passing over an icon to reach another doesn't shuffle the grid.
    private func scheduleReorder(to index: Int) {
        guard index != drag?.index else {
            reorderTask?.cancel()
            pendingIndex = nil
            return
        }
        guard index != pendingIndex else { return }
        pendingIndex = index
        reorderTask?.cancel()
        reorderTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled, let self else { return }
            withAnimation(Self.spring) { self.drag?.index = index }
            self.pendingIndex = nil
        }
    }

    /// Holding a dragged icon at the left or right edge turns the page, repeatedly.
    private func updateEdgeFlip() {
        guard drag != nil else { return }
        let location = dragLocation
        let edge: CGFloat = 40
        let area = contentArea
        let direction = location.x < area.minX + edge ? -1 : (location.x > area.maxX - edge ? 1 : 0)
        guard direction != edgeDirection else { return }
        edgeDirection = direction
        edgeTask?.cancel()
        guard direction != 0 else { return }
        edgeTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, let self else { return }
                self.goToPage(self.page + direction)
                self.updateDropTarget()
            }
        }
    }
}
