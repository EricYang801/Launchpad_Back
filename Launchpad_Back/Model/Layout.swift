import Foundation

nonisolated struct SavedFolder: Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var apps: [String]
}

nonisolated enum LayoutEntry: Codable, Hashable, Sendable {
    case app(String)
    case folder(SavedFolder)

    var id: String {
        switch self {
        case .app(let id): id
        case .folder(let folder): folder.id.uuidString
        }
    }

    func isVisible(_ installed: Set<String>) -> Bool {
        switch self {
        case .app(let id): installed.contains(id)
        case .folder(let folder): folder.apps.contains(where: installed.contains)
        }
    }
}

/// The user's arrangement of apps and folders.
///
/// Apps that are not installed right now (an unmounted drive, a pending reinstall) keep their
/// place in the saved layout but are hidden. Every index taken by the mutating methods counts
/// visible items only, which is what the grid shows.
nonisolated struct Layout: Codable, Equatable, Sendable {
    private(set) var entries: [LayoutEntry] = []

    // Not redundant: with `private(set)` the synthesized initializer would be private.
    init(entries: [LayoutEntry] = []) {
        self.entries = entries
    }

    func items(for apps: [String: AppItem]) -> [LaunchItem] {
        entries.compactMap { entry in
            switch entry {
            case .app(let id):
                return apps[id].map(LaunchItem.app)
            case .folder(let saved):
                let members = saved.apps.compactMap { apps[$0] }
                return members.isEmpty ? nil : .folder(Folder(id: saved.id, name: saved.name, apps: members))
            }
        }
    }

    /// Drops duplicate placements and appends apps that have no place yet, alphabetically.
    mutating func place(_ apps: [String: AppItem]) {
        var seen = Set<String>()
        var cleaned: [LayoutEntry] = []
        for entry in entries {
            switch entry {
            case .app(let id):
                if seen.insert(id).inserted { cleaned.append(entry) }
            case .folder(var saved):
                saved.apps = saved.apps.filter { seen.insert($0).inserted }
                if !saved.apps.isEmpty { cleaned.append(.folder(saved)) }
            }
        }
        let newcomers = apps.values
            .filter { !seen.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        entries = cleaned + newcomers.map { .app($0.id) }
    }

    /// Moves an item, or an app taken out of its folder, to `index` among the visible top-level items.
    mutating func move(_ id: String, to index: Int, installed: Set<String>) {
        guard let entry = take(id) else { return }
        let position = Self.position(ofVisible: index, in: entries) { $0.isVisible(installed) }
        entries.insert(entry, at: position)
    }

    /// Drops app `id` onto `targetID`, creating a folder or adding to one.
    /// Returns the folder the app ended up in.
    @discardableResult
    mutating func merge(_ id: String, into targetID: String, newFolderName: String) -> UUID? {
        let isFolder = entries.contains {
            if case .folder(let folder) = $0 { folder.id.uuidString == id } else { false }
        }
        guard id != targetID, !isFolder, !folderContains(targetID, id) else { return nil }
        guard entries.contains(where: { $0.id == targetID }), take(id) != nil,
            let index = entries.firstIndex(where: { $0.id == targetID })
        else { return nil }

        switch entries[index] {
        case .app(let targetApp):
            let folder = SavedFolder(id: UUID(), name: newFolderName, apps: [targetApp, id])
            entries[index] = .folder(folder)
            return folder.id
        case .folder(var folder):
            folder.apps.append(id)
            entries[index] = .folder(folder)
            return folder.id
        }
    }

    mutating func moveInFolder(_ folderID: UUID, app id: String, to index: Int, installed: Set<String>) {
        updateFolder(folderID) { folder in
            guard let from = folder.apps.firstIndex(of: id) else { return }
            folder.apps.remove(at: from)
            let position = Self.position(ofVisible: index, in: folder.apps) { installed.contains($0) }
            folder.apps.insert(id, at: position)
        }
    }

    mutating func rename(_ folderID: UUID, to name: String) {
        updateFolder(folderID) { $0.name = name }
    }

    // MARK: - Helpers

    private func folderContains(_ folderID: String, _ appID: String) -> Bool {
        entries.contains {
            if case .folder(let folder) = $0 {
                folder.id.uuidString == folderID && folder.apps.contains(appID)
            } else {
                false
            }
        }
    }

    private mutating func updateFolder(_ folderID: UUID, _ change: (inout SavedFolder) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == folderID.uuidString }),
            case .folder(var folder) = entries[index]
        else { return }
        change(&folder)
        entries[index] = .folder(folder)
    }

    /// Removes a top-level entry, or an app from its folder. A folder left with one app turns back into that app.
    private mutating func take(_ id: String) -> LayoutEntry? {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            return entries.remove(at: index)
        }
        for (index, entry) in entries.enumerated() {
            guard case .folder(var folder) = entry, let appIndex = folder.apps.firstIndex(of: id) else { continue }
            folder.apps.remove(at: appIndex)
            switch folder.apps.count {
            case 0: entries.remove(at: index)
            case 1: entries[index] = .app(folder.apps[0])
            default: entries[index] = .folder(folder)
            }
            return .app(id)
        }
        return nil
    }

    /// The array position in front of the `visibleIndex`-th visible element, or the end.
    static func position<T>(ofVisible visibleIndex: Int, in array: [T], isVisible: (T) -> Bool) -> Int {
        var seen = 0
        for (position, element) in array.enumerated() where isVisible(element) {
            if seen == visibleIndex { return position }
            seen += 1
        }
        return array.count
    }
}

// MARK: - Persistence

extension Layout {
    nonisolated static let storageKey = "layout.v2"

    nonisolated static func load(from defaults: UserDefaults) -> Layout {
        if let data = defaults.data(forKey: storageKey),
            let layout = try? JSONDecoder().decode(Layout.self, from: data)
        {
            return layout
        }
        return migrateLegacy(from: defaults)
    }

    nonisolated func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Reads the 2.x format: `launchpad_item_order` ("app:<id>" / "folder:<uuid>") plus `launchpad_folders`.
    nonisolated static func migrateLegacy(from defaults: UserDefaults) -> Layout {
        var folders: [String: SavedFolder] = [:]
        for case let data as [String: Any] in defaults.array(forKey: "launchpad_folders") ?? [] {
            guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
                let name = data["name"] as? String,
                let apps = (data["appIdentifiers"] ?? data["appBundleIds"]) as? [String], !apps.isEmpty
            else { continue }
            folders[id.uuidString] = SavedFolder(id: id, name: name, apps: apps)
        }

        var entries: [LayoutEntry] = []
        for key in defaults.stringArray(forKey: "launchpad_item_order") ?? [] {
            if key.hasPrefix("app:") {
                entries.append(.app(String(key.dropFirst(4))))
            } else if key.hasPrefix("folder:"), let folder = folders.removeValue(forKey: String(key.dropFirst(7))) {
                entries.append(.folder(folder))
            }
        }
        entries += folders.values.sorted { $0.name < $1.name }.map(LayoutEntry.folder)
        return Layout(entries: entries)
    }
}

// MARK: - Folder naming

nonisolated enum FolderName {
    /// Launchpad names a new folder after the App Store category of the apps in it.
    static func suggested(for apps: [AppItem]) -> String {
        for app in apps {
            if let category = app.category, let name = categoryName(category) { return name }
        }
        return String(localized: "Untitled")
    }

    static func categoryName(_ category: String) -> String? {
        switch category.replacingOccurrences(of: "public.app-category.", with: "") {
        case "business": String(localized: "Business")
        case "developer-tools": String(localized: "Developer Tools")
        case "education": String(localized: "Education")
        case "entertainment": String(localized: "Entertainment")
        case "finance": String(localized: "Finance")
        case let games where games.hasSuffix("games"): String(localized: "Games")
        case "graphics-design": String(localized: "Graphics & Design")
        case "healthcare-fitness": String(localized: "Health & Fitness")
        case "lifestyle": String(localized: "Lifestyle")
        case "medical": String(localized: "Medical")
        case "music": String(localized: "Music")
        case "news": String(localized: "News")
        case "photography": String(localized: "Photography")
        case "productivity": String(localized: "Productivity")
        case "reference": String(localized: "Reference")
        case "social-networking": String(localized: "Social Networking")
        case "sports": String(localized: "Sports")
        case "travel": String(localized: "Travel")
        case "utilities": String(localized: "Utilities")
        case "video": String(localized: "Video")
        case "weather": String(localized: "Weather")
        default: nil
        }
    }
}
