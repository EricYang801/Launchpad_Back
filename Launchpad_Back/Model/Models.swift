import Foundation

/// An installed application bundle.
nonisolated struct AppItem: Identifiable, Hashable, Sendable {
    /// Bundle identifier, or the bundle path when the app has none. Stable across launches.
    let id: String
    let name: String
    let url: URL
    /// `LSApplicationCategoryType`, used to name new folders the way Launchpad does.
    let category: String?
    /// Lowercased name, bundle name, bundle identifier and path, for substring search.
    let searchKey: String

    init(id: String, name: String, url: URL, category: String? = nil, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.url = url
        self.category = category
        self.searchKey = ([name] + aliases + [id, url.path]).joined(separator: "\n").lowercased()
    }
}

nonisolated struct Folder: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// Installed apps only; apps that are missing right now stay in the saved layout.
    var apps: [AppItem]
}

/// One cell of the Launchpad grid.
nonisolated enum LaunchItem: Identifiable, Hashable, Sendable {
    case app(AppItem)
    case folder(Folder)

    var id: String {
        switch self {
        case .app(let app): app.id
        case .folder(let folder): folder.id.uuidString
        }
    }

    var name: String {
        switch self {
        case .app(let app): app.name
        case .folder(let folder): folder.name
        }
    }

    var app: AppItem? {
        if case .app(let app) = self { app } else { nil }
    }
}
