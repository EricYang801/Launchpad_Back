import Foundation

/// Finds installed application bundles.
///
/// Roots are scanned in order and the first copy of a bundle identifier wins, so an app in
/// `/Applications` always beats a stale copy in a Homebrew Caskroom.
nonisolated struct AppScanner: Sendable {
    struct Root: Sendable {
        let url: URL
        /// How many folder levels below the root may hold apps (e.g. `/Applications/Adobe Photoshop/…app` is 2).
        let depth: Int
    }

    var roots: [Root]

    static let standard = AppScanner(roots: [
        Root(url: URL(fileURLWithPath: "/System/Applications"), depth: 2),
        Root(url: URL(fileURLWithPath: "/Applications"), depth: 3),
        Root(url: realHomeDirectory.appendingPathComponent("Applications"), depth: 3),
        Root(url: URL(fileURLWithPath: "/opt/homebrew/Caskroom"), depth: 3),
        Root(url: URL(fileURLWithPath: "/usr/local/Caskroom"), depth: 3),
    ])

    /// Hidden system helpers that live next to regular apps.
    static let excludedBundleIDs: Set<String> = [
        "com.apple.installer", "com.apple.LaunchPadMigrator", "com.apple.AirPlayUIAgent",
        "com.apple.SoftwareUpdateNotificationManager", "com.apple.CoreLocationAgent",
        "com.apple.OBEXAgent", "com.apple.ODSAgent", "com.apple.PIPAgent",
        "com.apple.ReportPanic", "com.apple.ScreenSaverEngine", "com.apple.loginwindow",
    ]

    /// The user's home even if the process were ever sandboxed (where `NSHomeDirectory()` is the container).
    static var realHomeDirectory: URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    func scan() -> [AppItem] {
        var seen = Set<String>()
        var apps: [AppItem] = []
        for root in roots {
            for url in bundles(in: root.url, depth: root.depth) {
                guard let app = Self.cachedApp(at: url), seen.insert(app.id).inserted else { continue }
                apps.append(app)
            }
        }
        return apps
    }

    /// Parsed bundles keyed by path. Launchpad rescans on every open; an app whose Info.plist hasn't changed
    /// since the last scan isn't read again.
    private static let cache = AppCache()

    private static func cachedApp(at url: URL) -> AppItem? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        let modified = (try? FileManager.default.attributesOfItem(atPath: plist.path)[.modificationDate]) as? Date
        if let modified, let entry = cache[url.path], entry.modified == modified { return entry.app }
        let app = makeApp(at: url)
        if let modified { cache[url.path] = (modified, app) }
        return app
    }

    private func bundles(in directory: URL, depth: Int) -> [URL] {
        let fileManager = FileManager.default
        guard depth > 0, let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }

        var result: [URL] = []
        for name in names.sorted() where !name.hasPrefix(".") {
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            if name.hasSuffix(".app") {
                result.append(url)
            } else {
                result += bundles(in: url, depth: depth - 1)
            }
        }
        return result
    }

    static func makeApp(at url: URL) -> AppItem? {
        let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any] ?? [:]
        let bundleID = info["CFBundleIdentifier"] as? String ?? ""
        guard !excludedBundleIDs.contains(bundleID), info["LSBackgroundOnly"] as? Bool != true else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let plistNames = ["CFBundleDisplayName", "CFBundleName"].compactMap { info[$0] as? String }
        // Finder's display name is localized ("系統設定" for System Settings); some apps ship an empty one.
        let name =
            ([FileManager.default.displayName(atPath: url.path)] + plistNames + [fileName])
            .map { ($0.hasSuffix(".app") ? String($0.dropLast(4)) : $0).trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? fileName

        return AppItem(
            id: bundleID.isEmpty ? url.path : bundleID,
            name: name,
            url: url,
            category: info["LSApplicationCategoryType"] as? String,
            aliases: plistNames + [fileName]
        )
    }
}

/// Thread-safe storage for `AppScanner`'s parsed bundles; scans run off the main thread.
private nonisolated final class AppCache: @unchecked Sendable {
    private var entries: [String: (modified: Date, app: AppItem?)] = [:]
    private let lock = NSLock()

    subscript(path: String) -> (modified: Date, app: AppItem?)? {
        get { lock.withLock { entries[path] } }
        set { lock.withLock { entries[path] = newValue } }
    }
}
