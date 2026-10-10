import Foundation
@testable import Launchpad_Back

func makeApp(_ name: String, id: String? = nil, category: String? = nil) -> AppItem {
    AppItem(
        id: id ?? "com.test.\(name.lowercased())",
        name: name,
        url: URL(fileURLWithPath: "/Applications/\(name).app"),
        category: category
    )
}

func appMap(_ apps: [AppItem]) -> [String: AppItem] {
    Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
}

func makeDefaults() -> UserDefaults {
    let name = "LaunchpadTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

extension Array where Element == LaunchItem {
    var names: [String] { map(\.name) }
}
